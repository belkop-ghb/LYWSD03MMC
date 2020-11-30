#!/bin/bash
# This script uses common linux applications to get Temperature, Humidify and Battery level from Xiaomi LYWSD03MMC  sensor.
#
# This script is a modification from original version.
# Thanks to the author.
#
# Reference: http://www.d0wn.com/using-bash-and-gatttool-to-get-readings-from-xiaomi-mijia-lywsd03mmc-temperature-humidity-sensor/
#            https://github.com/thiagogalvao/LYWSD03MMC
#
# This version works fine in a Raspberry Pi 3+.
#
# Dependences (often resolved with apt install):
# - gatttool (to work with BLE)
# - awk
# - bc
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

DEBUG=1

SENSORS=( "livingroom#a4:c1:38:0a:5b:87")

for item in "${SENSORS[@]}" ; do
    name="${item%%#*}"
    mac_address="${item##*#}"
	
    debug_print "MAC:"$mac_address
    debug_print "SensorName:"$name

    data=$(timeout 15 gatttool -b $mac_address --char-write-req --handle='0x0038' --value="0100" --listen  | grep "Notification handle" -m 1)
    if [ -z "$data" ]
    then
        debug_print "The reading failed"
    else
        debug_print "Got data"        
	
	temphexa=$(echo $data | awk -F ' ' '{print $7$6}'| tr [:lower:] [:upper:] )
        temperature100=$(echo "ibase=16; $temphexa" | bc)
	temperature=$(echo "scale=2;$temperature100/100"|bc)
	
	humhexa=$(echo $data | awk -F ' ' '{print $8}'| tr [:lower:] [:upper:])		
        humidity=$(echo "ibase=16; $humhexa" | bc)	
        
	battery=$(timeout 15 gatttool -b $mac_address --char-read --uuid 0x2a19  | awk '{print "ibase=16;", $4}' | bc)
		
        debug_print "Temp:"$temperature
        debug_print "Hum:"$humidity
	debug_print "Batt:"$battery
    fi
done
