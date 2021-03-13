#!/bin/bash
#
# Simple script to report temperature, humidity and battery level of
# Xiaomi Mijia Bluetooth Temperature and Humidity Sensor LYWSD03MMC to MQTT.
# Requires gatttool, mosquitto_pub, bc and xxd tools to be installed.
#
# On Ubuntu 18.04 the required packages can be installed with:
# apt install xxd bc mosquitto-clients bluez
#
# This is a modification of multiple previous scripts. Thanks to the authors.
#
### Defaults

MAXRETRY=5
MQTT_TOPIC_PREFIX=""

#######################################################################
# No need to change things below this line.
#######################################################################

SENSOR_ADDRESS=""
SENSOR_NAME=""
DEBUG=0

#######################################################################
# No need to change things below this line.
#######################################################################
BATTERY_MIN=2100
BATTERY_MAX=3100

readonly USAGE="
$0 -a [address] -n [sensor name]

Mandatory arguments:

-a  | --address           Bluetooth MAC address of sensor.
-n  | --name              Name of the sensor to use for MQTT.

Optional arguments:

-b  | --broker            MQTT broker address.
-u  | --usr            	  MQTT broker user.
-P  | --pwd               MQTT broker password.
-r  | --retries           Number of max retry attempts. Default $MAXRETRY times.
-p  | --prefix            MQTT topic prefix. Default $MQTT_TOPIC_PREFIX.
-d  | --debug             Enable debug printouts.
-h  | --help
"

debug_print() {
	if [ $DEBUG -eq 1 ]; then
		echo "$@"
	fi
}

print_usage() {
	echo "${USAGE}"
}

parse_command_line_parameters() {
	while [[ $# -gt 0 ]]
	do
		key="$1"

		case $key in
			-a|--address)
			SENSOR_ADDRESS="$2"
			shift; shift
    			;;
			-n|--name)
			SENSOR_NAME="$2"
			shift; shift
			;;
			-b|--broker)
			BROKER_IP="$2"
			shift; shift
			;;
			-u|--usr)
			BROKER_USR="$2"
			shift; shift
			;;
			-P|--pwd)
			BROKER_PWD="$2"
			shift; shift
			;;
			-r|--retries)
			MAXRETRY="$2"
			shift; shift
			;;
			-p|--prefix)
			MQTT_TOPIC_PREFIX="$2"
			shift; shift
			;;
			-d|--debug)
			DEBUG=1
			shift; shift
			;;
			-h|--help)
			print_usage
			exit 0
			;;
    			*)
			# Unknown parameter
			print_usage
			exit 1
			;;
		esac
	done

	if [ -z $SENSOR_NAME ]; then
		echo "Sensor name is mandatory parameter."
		print_usage
		exit 2
	fi

	if [ -z $SENSOR_ADDRESS ]; then
		echo "Sensor address is mandatory parameter."
		print_usage
		exit 2
	fi

}

main() {

	local retry=0
	while true
	do
		debug_print "Querying $SENSOR_ADDRESS for temperature and humidity data."
		data=$(timeout 15 gatttool -b $SENSOR_ADDRESS --char-write-req --handle='0x0038' --value="0100" --listen  | grep "Notification handle" -m 1)
		rc=$?
		if [ ${rc} -eq 0 ]; then
			break
		fi
		if [ $retry -eq $MAXRETRY ]; then
		debug_print "$MAXRETRY attemps made, aborting."
			break
		fi
		retry=$((retry+1))
		debug_print "Connection failed, retrying $retry/$MAXRETRY... "
		sleep 5
	done

	debug_print "data: $data"

	temphexa=$(echo $data | awk -F ' ' '{print $7$6}'| tr [:lower:] [:upper:] )
	temperature100=$(echo "ibase=16; $temphexa" | bc)
	temperature=$(echo "scale=1;$temperature100/100"|bc)

	humhexa=$(echo $data | awk -F ' ' '{print $8}'| tr [:lower:] [:upper:])
	humidity=$(echo "ibase=16; $humhexa" | bc)

	bathexa=$(echo $data | awk -F ' ' '{print $10$9}'| tr [:lower:] [:upper:] )
	bat1000=$(echo "ibase=16; $bathexa" | bc)
	bat=$(echo "scale=2;$bat1000/1000" | bc)

	debug_print "BAT1000: $bat1000"
	debug_print "BAT: $bat"

	if ((bat1000>BATTERY_MAX));
	then
		bat_perc=100.0
	else
		bat_perc=$(echo "a=(($bat1000-$BATTERY_MIN) / ($BATTERY_MAX - $BATTERY_MIN)*100); scale=0; a/1" | bc -l)
	fi

	debug_print "Temperature: $temperature, Humidity: $humidity, Battery: $bat_perc"

	MQTT_TOPIC="$SENSOR_NAME"
	if [ -n "$MQTT_TOPIC_PREFIX" ]
	then
		MQTT_TOPIC="$MQTT_TOPIC_PREFIX/$MQTT_TOPIC"
	fi



	valid=1

	if [[ "$temperature" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] && [[ "$humidity" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$bat_perc" =~ ^[0-9]+(\.[0-9]+)?$ ]];
	then
		debug_print "Values are valid"
		mosquitto_pub -h $BROKER_IP -u $BROKER_USR -P $BROKER_PWD -i "mibridge" -t $MQTT_TOPIC"_temperature/config" -m '{"device_class": "temperature", "name": "'$SENSOR_NAME'_temperature", "unique_id": "lywsd03mmc_'$SENSOR_NAME'_temperature", "device": { "name":"lywsd03mmc_'$SENSOR_NAME'", "identifiers": "lywsd03mmc_'$SENSOR_NAME'", "model": "LYWSD03MMC", "manufacturer": "Xiaomi"}, "state_topic": "'$MQTT_TOPIC'/state", "unit_of_measurement": "°C", "value_template": "'$temperature'","platform": "mqtt" }'
		mosquitto_pub -h $BROKER_IP -u $BROKER_USR -P $BROKER_PWD -i "mibridge" -t $MQTT_TOPIC"_humidity/config" -m '{"device_class": "humidity", "name": "'$SENSOR_NAME'_humidity", "unique_id": "lywsd03mmc_'$SENSOR_NAME'_humidity", "device": { "name":"lywsd03mmc_'$SENSOR_NAME'", "identifiers": "lywsd03mmc_'$SENSOR_NAME'", "model": "LYWSD03MMC", "manufacturer": "Xiaomi"}, "state_topic": "'$MQTT_TOPIC'/state", "unit_of_measurement": "%", "value_template": "'$humidity'","platform": "mqtt" }'
		mosquitto_pub -h $BROKER_IP -u $BROKER_USR -P $BROKER_PWD -i "mibridge" -t $MQTT_TOPIC"_battlevel/config" -m '{"device_class": "battery", "name": "'$SENSOR_NAME'_battery", "unique_id": "lywsd03mmc_'$SENSOR_NAME'_battery", "device": { "name":"lywsd03mmc_'$SENSOR_NAME'", "identifiers": "lywsd03mmc_'$SENSOR_NAME'", "model": "LYWSD03MMC", "manufacturer": "Xiaomi"}, "state_topic": "'$MQTT_TOPIC'/state", "unit_of_measurement": "%", "value_template": "'$bat_perc'","platform": "mqtt" }'
		mosquitto_pub -h $BROKER_IP -u $BROKER_USR -P $BROKER_PWD -i "mibridge" -t $MQTT_TOPIC"/state" -m '{ "temperature": '$temperature', "humidity": '$humidity', "batterylevel": '$bat_perc' }'
		debug_print "Done"
	fi


}


parse_command_line_parameters $@
main

