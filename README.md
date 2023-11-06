# ookla-service
This is an unofficial fork of Ookla's installation script for their Ookla Speedtest Server. Some of the differences
include:
- Creating a Service unit for SystemCTL to auto-start the daemon on boot
- Creating a central PID file for process termination

### Install the Ookla Service

1. Create the directory you wish run this service in:
   1. ```shell
      sudo mkdir -p /opt/OoklaSpeedtest \
      && sudo chown -R $USER:$USER /opt/OoklaSpeedtest \
      && cd /opt/OoklaSpeedtest/ 
      ```
2. Clone this repo into your working directory
   1. ```shell
      git clone https://github.com/VisionaryBroadband/ookla-service.git ./ \
      && chmod +x ooklaserver.sh
      ```
3. Run the installation script to pull the latest daemon files from Ookla
   1. ```shell
      /bin/sh ooklaserver.sh install
      ```
   2. The script will attempt to detect the platform, if that fails please select your platform from the prompt.
   3. Next the script will confirm you desire to install the files
   4. Then the script will proceed to download the latest files directly from Ookla
   5. Finally, the script will complete the installation by starting the service up and checking if all is working
4. If the installation completed successfully, you will stop the daemon and then start and enable the service,
so it will run automatically on each boot.
   1. ```shell
      ./ooklaserver.sh stop
      ```
   2. ```shell
      sudo systemctl start OoklaServer \
      && sudo systemctl enable OoklaServer \
      && Sudo systemctl status OoklaServer
      ```
      
### References

- [OoklaServer Installation - Linux / Unix](https://support.ookla.com/hc/en-us/articles/234578528-OoklaServer-Installation-Linux-Unix)
- [Ookla Linux Startup Script Options](https://support.ookla.com/hc/en-us/articles/234578588-Linux-Startup-Script-Options)
- [JMF-Networks](https://gist.github.com/JMF-Networks/367b6bc20b2e4120d6b17538ee6f8b52)

### Credits

- Ookla, LLC.