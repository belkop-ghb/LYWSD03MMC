Are you using Xiaomi LYWSD03MMC bluetooth temperature sensors and want to use the built-in bluetooth receiver on your computer to receive the data? These scripts can help you to do this.

There are three scripts in the repository:

- readSensors.sh
- writeToMqtt.sh
- writeToMqttHA.sh

readSensors.sh - just for test purpose. Define an array of your sensors (name#MAC address) and run the script. Sensor data will be displayed in the console.

writeToMqtt.sh - script with many input params. This can be used to read the data from sensor and write them to the MQTT broker. This script can be called within a cron job.

Example: 
```sh
./writeToMqtt.sh -a a4:c1:0a:b2:6c:87 -n livingroom -r 3 -b 192.168.0.2 -u brokerUsername -P brokerPassword -d
```

writeToMqttHA.sh - similar to the writeToMqtt, but writes the data to MQTT in a HomeAssistant format. HomeAssistant can find the devices via MQTT autodiscovery.

Example: 
```
./writeToMqttHA.sh --address a4:c1:0a:b2:6c:87 --name livingroom --retries 5 --broker 192.168.0.2 --prefix /homeassistant --usr brokerUsername --pwd brokerPassword --debug
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

If you find this code helpful, you can buy me a coffee ;-)
<p data-sourcepos="275:1-275:227" dir="auto"><a href="https://www.buymeacoffee.com/belkop" rel="nofollow"><img src="https://camo.githubusercontent.com/bb1379389889e9a4bb06b016d3ab5a1d6d3517bf10229c7364775620efbaa625/68747470733a2f2f7777772e6275796d6561636f666665652e636f6d2f6173736574732f696d672f637573746f6d5f696d616765732f77686974655f696d672e706e67" alt="Buy Me A Coffee" data-canonical-src="https://www.buymeacoffee.com/assets/img/custom_images/white_img.png" style="max-width: 100%;"></a></p>
