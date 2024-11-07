# ookla-service
This is an unofficial fork of Ookla's installation script for their Ookla Speedtest Server. Some of the differences
include:
- Creating a Service unit for SystemCTL to auto-start the daemon on boot and restart if failed
- Creating a central PID file for process termination
- Create a logrotate conf so the scripts logs get rotated
- Script runs on Bash instead of Posix and favors Debian based systems
- Script has much better error handling and logging and included a debug mode for verbose console output

### Install the Ookla Service

1. Clone this repo into your home directory
   1. ```shell
      git clone https://github.com/VisionaryBroadband/ookla-service.git 
      ```
2. Enter the repo directory and run the installation script to pull the latest daemon files from Ookla
   1. ```shell
      cd ookla-service \
      && ./ooklaserver.sh -v install
      ```
   2. The script will attempt to detect the platform, if that fails please select your platform from the prompt.
   3. Next the script will confirm you desire to install the files
   4. Then the script will proceed to download the latest files directly from Ookla
   5. Finally, the script will complete the installation by starting the service up and checking if all is working
3. If the installation completed successfully, you will stop the daemon and then start and enable the service,
so it will run automatically on each boot.
   1. ```shell
      ./ooklaserver.sh -v stop
      ```
   2. ```shell
      sudo systemctl enable OoklaServer \
      && sudo systemctl start OoklaServer \
      && sudo systemctl status OoklaServer
      ```

### References

- [OoklaServer Installation - Linux / Unix](https://support.ookla.com/hc/en-us/articles/234578528-OoklaServer-Installation-Linux-Unix)
- [Ookla Linux Startup Script Options](https://support.ookla.com/hc/en-us/articles/234578588-Linux-Startup-Script-Options)
- [JMF-Networks](https://gist.github.com/JMF-Networks/367b6bc20b2e4120d6b17538ee6f8b52)

### Credits

- Ookla, LLC.