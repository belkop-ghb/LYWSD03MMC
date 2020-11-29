#!/bin/bash
# This script uses common linux applications to get Temperature e Humidify data from Xiaomi LYWSD03MMC sensor.
#
# This script is a modification from original version to use mosquitto_pub to send data over MQTT to a broker.
# Thanks to the author.
#
# Reference: http://www.d0wn.com/using-bash-and-gatttool-to-get-readings-from-xiaomi-mijia-lywsd03mmc-temperature-humidity-sensor/
#
# This version works fine in a Raspberry Pi 3+.
# Use crontab to scheduler an execution every minute.
#
# Dependences (often resolved with apt install):
# - gatttool (to work with BLE)
# - awk
# - bc
# - mosquitto_pub
#
# Use the command below to find the device mac address 
#    sudo hcitool lescan
#
# 

debug_print() {
	if [ $DEBUG -eq 1 ]; then
		echo "$@"
	fi
}

#sensor_name="Sensor"
#mac_address_list=("a4:c1:38:0a:5b:87" "A4:C1:38:00:00:02")
#mac_address_list=(["bedroom"]="a4:c1:38:0a:5b:87")
mqtt_server="192.168.77.130"
DEBUG=1


ARRAY=( "livingroom#a4:c1:38:0a:5b:87")

for item in "${ARRAY[@]}" ; do
    room="${item%%#*}"
    mac_address="${item##*#}"
	
	debug_print "MAC:"$mac_address
	debug_print "SensorName:"$room

    data=$(timeout 15 gatttool -b $mac_address --char-write-req --handle='0x0038' --value="0100" --listen  | grep "Notification handle" -m 1)
    if [ -z "$data" ]
    then
        debug_print "The reading failed"
    else
        debug_print "Got data"
        temphexa=$(echo $data | awk -F ' ' '{print $7$6}'| tr [:lower:] [:upper:] )
        humhexa=$(echo $data | awk -F ' ' '{print $8}'| tr [:lower:] [:upper:])
		
        temperature100=$(echo "ibase=16; $temphexa" | bc)
		
        humidity=$(echo "ibase=16; $humhexa" | bc)
        temperature=$(echo "scale=2;$temperature100/100"|bc)
		battery=$(gatttool -b $mac_address --char-read --uuid 0x2a19  | awk '{print "ibase=16;", $4}' | bc)
		
        debug_print "Temp:"$temperature
        debug_print "Hum:"$humidity
		debug_print "Batt:"$battery
  
 #       if [ ! ${#temperature} -ge 6 ] 
 #       then
#		   debug_print "Writing temperature to MQTT"
 #          mosquitto_pub -h $mqtt_server -u rpiBrokerUSR -P rpiBrokerPWD  -m $temperature -t /$room/temperature -d
 #       fi

 #       if [ ! ${#humidity} -ge 3 ] 
 #       then
 #          mosquitto_pub -h $mqtt_server -m $humidity -t /LYWSD03MMC/$sensor_name_idx/Humidity -d
 #       fi
    fi
done