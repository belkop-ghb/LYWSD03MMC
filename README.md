There are two scripts in the repository:

- readSensors.sh
- writeToMqtt.sh

readSensors.sh - just for test purpose. Define an array of your sensors (name#MAC address) and run the script. Sensor data will be displayed in the console.

writeToMqtt.sh - script with many input params. This can be used to read the data from sensor and write them to the MQTT broker. This script can be called within a cron job.

Example: 
```sh
./writeToMqtt.sh -a a4:c1:0a:b2:6c:87 -n livingroom -r 3 -b 192.168.0.2 -u brokerUsername -P brokerPassword -d
```

Feel free to modify the code according to your needs.

If you find this code helpful, you can buy me a coffee ;-) -
https://www.buymeacoffee.com/belkop
