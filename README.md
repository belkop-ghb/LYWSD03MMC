There are two scripts in the repository:

- readSensors.sh
- writeToMqtt.sh

readSensors.sh - just for test purpose. Define an array of your sensors (name#MAC address) and run the script. Sensor data will be displayed in the console.

writeToMqtt.sh - script with many input params. This can be used to read the data from sensor and write them to the MQTT broker. This script can be called within a cron job.

Example: 
```sh
./writeToMqtt.sh -a a4:c1:0a:b2:6c:87 -n livingroom -r 3 -b 192.168.0.2 -u brokerUsername -P brokerPassword -d
```

Required software:
- sudo apt install bluez

If you are running Ubuntu on RPI, you may need:
- sudo apt install pi-bluetooth


Troubleshooting:
- _systemctl status bluetooth_ - checks bluetooth status (should be *active*)
- _bluetoothctl_ - starts bluetooth utility
  - _power on_
  - _list_ - lists the host's controller
  - _scan on_ - scans the nearby devices
  - _scan off_ - stop scanning

Feel free to modify the code according to your needs.

If you find this code helpful, you can buy me a coffee ;-) -
https://www.buymeacoffee.com/belkop
