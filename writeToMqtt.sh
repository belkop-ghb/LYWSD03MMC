#!/bin/bash
#
# Simple script to report temperature, humidity and battery level of
# Xiaomi Mijia Bluetooth Temperature and Humidity Sensor to MQTT.
# Requires gatttool, mosquitto_pub, bc and xxd tools to be installed.
#
# On Ubuntu 18.04 the required packages can be installed with:
# apt install xxd bc mosquitto-clients bluez
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

retry=0
while true
do
    debug_print "Querying $SENSOR_ADDRESS for battery data."
    battery=$(timeout 15 gatttool -b $SENSOR_ADDRESS --char-read --uuid 0x2a19  | awk '{print "ibase=16;", $4}' | bc)
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

temphexa=$(echo $data | awk -F ' ' '{print $7$6}'| tr [:lower:] [:upper:] )
humhexa=$(echo $data | awk -F ' ' '{print $8}'| tr [:lower:] [:upper:])

temperature100=$(echo "ibase=16; $temphexa" | bc)

humidity=$(echo "ibase=16; $humhexa" | bc)
temperature=$(echo "scale=2;$temperature100/100"|bc)
debug_print "data: $data"


debug_print "Temperature: $temperature, Humidity: $humidity, Battery: $battery"
MQTT_TOPIC="$SENSOR_NAME"
if [ -n "$MQTT_TOPIC_PREFIX" ]
then
	MQTT_TOPIC="$MQTT_TOPIC_PREFIX/$MQTT_TOPIC"
fi

if [ -n "$BROKER_IP" ]; then
	debug_print "Broker set!"
	# Do validity check and publish
	if [[ "$temperature" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
	then
		mqtt_publish "$MQTT_TOPIC/temperature" "$temperature"
	else
		echo "Temperature not valid: $temperature"
	fi

	if [[ "$humidity" =~ ^[0-9]+(\.[0-9]+)?$ ]]
	then
		mqtt_publish "$MQTT_TOPIC/humidity" "$humidity"
	else
		echo "Humidity not valid: $humidity"
	fi

	if [[ "$battery" =~ ^[0-9]+(\.[0-9]+)?$ ]]
	then
		mqtt_publish "$MQTT_TOPIC/battery" "$battery"
	else
		echo "Battery level not valid: $battery"
	fi
else
  debug_print "Broker not set."
fi




}

mqtt_publish() {
	local topic=$1
	local value=$2
	COMMAND="mosquitto_pub -h $BROKER_IP"
	if [ -n "$BROKER_USR" ]
	then
		COMMAND="$COMMAND -u $BROKER_USR"
	fi
	if [ -n "$BROKER_PWD" ]
	then
		COMMAND="$COMMAND -P $BROKER_PWD"
	fi
	
	COMMAND="$COMMAND -t $topic -m $value"
	debug_print "Command: $COMMAND"
	
	published=eval ${COMMAND}
	rc=$?
	if [ ${rc} -eq 0 ]; then
		debug_print "Publishing value as $topic"
		else
		debug_print "Publishing failed"
	fi
}

parse_command_line_parameters $@
main

