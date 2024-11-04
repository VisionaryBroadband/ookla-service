#!/bin/sh
##################
# OoklaServer install and management script
# (C) 2024 Ookla
##################
# Last Update 2024-01-30

BASE_DOWNLOAD_PATH="https://install.speedtest.net/ooklaserver/stable/"
DAEMON_FILE="OoklaServer"
INSTALL_DIR=''
PID_FILE="$DAEMON_FILE.pid"
dir_full=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

display_usage() {
  echo "OoklaServer installation and Management Script"
  echo  "Usage:"
  echo  "$0 [-f|--force] [-i|--installdir <dir>] command"
  echo  ""
  echo  "  Valid commands: install, start, stop, restart"
  echo  "   install - downloads and installs OoklaServer"
  echo  "   start   - starts OoklaServer if not running"
  echo  "   stop    - stops OoklaServer if running"
  echo  "   restart - stops OoklaServer if running, and restarts it"
  echo  " "
  echo  "  -f|--force           Do not prompt before install"
  echo  "  -i|--install <dir>   Install to specified folder instead of the current folder"
  echo  "  -h|--help            This help"
  echo  ""
  }

has_command() {
  type "$1" >/dev/null 2>&1
}

detect_platform() {
  # detect operating system
  case $( uname -s ) in
  Darwin)
    server_package='macosx';;
  Linux)
    server_package='linux-aarch64-static-musl'
    arch=$(uname -m)
    if [ "$arch" = "x86_64" ]
    then
      server_package='linux-x86_64-static-musl'
    fi;;
  FreeBSD)
    server_package='freebsd13_64';;
  *)
    echo "Please Select the server Platform : "
    echo "1) macOS"
    echo "2) Linux (aarch64)"
    echo "3) Linux (x86_64)"
    echo "4) FreeBSD (64bit)"

    read -r n
    case $n in
      1) server_package='macosx';;
      2) server_package='linux-aarch64-static-musl';;
      3) server_package='linux-x86_64-static-musl';;
      4) server_package='freebsd13_64';;
      *)
        printf "Invalid selection!"
        return 1;;
    esac
  esac

  echo "Server Platform is $server_package"
}

confirm_install() {
  if [ "${INSTALL_DIR}" != "" ]
  then
    printf "%s" "This will install the Ookla server for $server_package to folder $INSTALL_DIR. Please confirm (y/n) > "
  else
    printf "%s" "This will install the Ookla server for $server_package to the current folder. Please confirm (y/n) > "
  fi
  read -r response
  if [ "${response}" != "y" ]
  then
    echo "Exiting program."
    return 1
   fi
}

goto_speedtest_folder() {
  # determine if base install folder exists
  dir_base=$(basename "${dir_full}")

  if [ "${INSTALL_DIR}" != "" ]
  then
    echo "Checking Directory Structure"
    if [ "${dir_base}" != "${INSTALL_DIR}" ]
    then
      if [ ! -d "${INSTALL_DIR}" ]
      then
        mkdir "${INSTALL_DIR}"
        scriptname=$(basename $0)
        # copy script to folder
        cp "${scriptname}" "${INSTALL_DIR}"
      fi
      cd "${INSTALL_DIR}" || echo "Failed install to ${INSTALL_DIR}" && return 1
    fi
  fi
}

download_install() {
  # download the v3 server files with either wget or curl or fetch
  gzip_download_file="OoklaServer-${server_package}.tgz"
  gzip_download_url="${BASE_DOWNLOAD_PATH}${gzip_download_file}"

  curl_path=$(command -v curl)
  wget_path=$(command -v wget)
  fetch_path=$(command -v fetch)

  echo "Downloading Server Files"
  if [ -n "${curl_path}" ]
  then
    curl -O "${gzip_download_url}"
  elif [ -n "${wget_path}" ]
  then
    wget "${gzip_download_url}" -O "${gzip_download_file}"
  elif [ -n "${fetch_path}" ]
  then
    # fetch is found in base OS in FreeBSD
    fetch -o "${gzip_download_file}" "${gzip_download_url}"
  else
    echo "This script requires CURL or WGET or FETCH"
    return 1
  fi

  # extract package
  if [ -f "${gzip_download_file}" ]
  then
    echo "Extracting Server Files"
    tar -zxovf "${gzip_download_file}"
    rm "${gzip_download_file}"
    if [ ! -f "${DAEMON_FILE}.properties" ]
    then
      cp "${DAEMON_FILE}.properties.default" "${DAEMON_FILE}.properties"
    fi
  else
    echo "Error downloading server package"
    return 1
  fi

  # Deploy service unit and reload the daemon
  printf "Would you like to install this as a Service for start on boot functionality? Please confirm (y/n) > "
  read -r svcResponse
  if [ "${svcResponse}" = "y" ]
  then
    if ! cp "OoklaServer.service.example" "OoklaServer.service"
    then
      printf "Failed to create OoklaServer.service file from example, please check permissions and try again"
      return 1
    fi
    printf "You may be prompted for a sudo password next to make the symbolic link to /etc/systemd/ and to reload the systemctl-daemon\n"
    # Update the USER/GROUP in the service file
    if ! sed -i '/User= #/c\User='"${USER}" 'OoklaServer.service'
    then
      printf "Failed to set the user on OoklaServer.service, please set manually"
    fi
    if ! sed -i '/Group= #/c\Group='"${USER}" 'OoklaServer.service'
    then
      printf "Failed to set the group on OoklaServer.service, please set manually"
    fi
    if ! sed -i '/WorkingDirectory=/c\WorkingDirectory='"${dir_full}/" 'OoklaServer.service'
    then
      printf "Failed to set filepath on WorkingDirectory in OoklaServer.service, please set manually"
    fi
    if ! sed -i '/PIDFile=/c\PIDFile='"${dir_full}/OoklaServer.pid" 'OoklaServer.service'
    then
      printf "Failed to set filepath on PIDFile in OoklaServer.service, please set manually"
    fi
    if ! sed -i '/ExecStart=/c\ExecStart='"${dir_full}/ooklaserver.sh start" 'OoklaServer.service'
    then
      printf "Failed to set filepath on ExecStart cmd in OoklaServer.service, please set manually"
    fi
    if ! sed -i '/ExecReload=/c\ExecReload='"${dir_full}/ooklaserver.sh restart" 'OoklaServer.service'
    then
      printf "Failed to set filepath on ExecReload cmd in OoklaServer.service, please set manually"
    fi
    if ! sed -i '/ExecStop=/c\ExecStop='"${dir_full}/ooklaserver.sh stop" 'OoklaServer.service'
    then
      printf "Failed to set filepath on ExecStop cmd in OoklaServer.service, please set manually"
    fi
    # Create the Symbolic link
    if ! sudo ln -s "${dir_full}/OoklaServer.service" "/etc/systemd/system/OoklaServer.service"
    then
      printf "Failed to install OoklaServer service!"
      return 1
    fi
    # Reload the systemctl daemon
    if ! sudo systemctl daemon-reload
    then
      printf "Failed to reload the systemctl daemon"
      return 1
    fi
  fi
}

restart_if_running() {
  if ! stop_if_running
  then
    return 1
  fi
  if ! start
  then
    return 1
  fi
}

stop_process() {
  daemon_pgid="$1"
  printf "%s" "Stopping $DAEMON_FILE Daemon ($daemon_pgid)"
  kill -SIGTERM -- -${daemon_pgid} 2>/dev/null 1>&2
  i=0
  while [ "$i" -lt 10 ]
  do
    if kill -0 -${daemon_pgid} 2>/dev/null 1>&2
    then
      # Process is still active, sleep and recheck
      sleep 1
      printf " ."
    else
      # Process doesn't exist, move on
      break
    fi
    i=$((i+1))
  done
  echo ""
  # Check if the process was successfully stopped
  if kill -0 -${daemon_pgid} 2>/dev/null 1>&2
  then
    # Process failed to stop, send SIGKILL
    if (kill -SIGKILL -- -${daemon_pgid} 2>/dev/null 1>&2)
    then
      return 0
    else
      return 1
    fi
  else
    # Process stopped successfully
    return 0
  fi
}

stop_if_running() {
  if [ -f "${dir_full}/${PID_FILE}" ]
  then
    daemon_pid=$(cat "${dir_full}/${PID_FILE}")
    if [ "${daemon_pid}" ]
    then
      # Get the Process Group ID (PGID) to stop all processes in the forked hierarchy
      main_pgid=$(ps -o pgid= -p "${daemon_pid}" | grep -o '[0-9]*')
      # Verify a PGID was returned
      if [ -n "${main_pgid}" ]
      then
        if stop_process "${main_pgid}"
        then
          echo "Successfully stopped OoklaServer"
          return 0
        else
          echo "Failed to stop OoklaServer"
          return 1
        fi
      else
        # Did not get a PGID, falling back to Process ID
        if has_command pgrep
        then
          pids=$(pgrep OoklaServer 2>&1 | sed -z 's/\n/ /g' | xargs)
          if [ -n "${pids}" ]
          then
            echo "Additional ${DAEMON_FILE} processes running; killing (${pids})"
            if (pgrep OoklaServer | xargs kill -9)
            then
              echo "Successfully stopped OoklaServer"
              return 0
            else
              echo "Failed to stop OoklaServer"
              return 1
            fi
          else
            echo "No OoklaServer processes found"
            return 0
          fi
        fi
      fi
    fi
  fi
}

start_if_not_running() {
  if [ -f "${PID_FILE}" ]
  then
    daemon_pid=$(cat "${dir_full}/${PID_FILE}")
    if [ "${daemon_pid}" ]
    then
      if kill -0 "${daemon_pid}" > /dev/null 2>&1
      then
        echo "${DAEMON_FILE} (${daemon_pid}) is already running"
        return 0
      fi
    fi
  fi
  if ! start
  then
    return 1
  fi
}

start() {
  printf '%s' "Starting $DAEMON_FILE"
  if [ -f "${dir_full}/${DAEMON_FILE}" ]; then
    chmod +x "${dir_full}/${DAEMON_FILE}"
    daemon_cmd="${dir_full}/${DAEMON_FILE} --daemon --pidfile=${dir_full}/${PID_FILE}"
    $daemon_cmd
  else
    echo ""
    echo "Daemon not installed. Please run install first."
    exit 1
  fi

  # wait for PID file to be created and verify daemon started
  i=0
  while [ "$i" -lt 10 ]
  do
    sleep 1
    if [ -f "${dir_full}/${PID_FILE}" ]
    then
      break
    fi
    printf " ."
    i=$((i+1))
  done
  echo ""
  if [ -f "${dir_full}/${PID_FILE}" ]
  then
    daemon_pid=$(cat "${dir_full}/${PID_FILE}")
    echo "Daemon Started (${daemon_pid})"
    return 0
  else
    echo "Failed to Start Daemon"
    return 1
  fi
}

##### Main

prompt=1
action='help'
while [ "$1" != "" ]
do
  case $1 in
    install ) action='install';;
    stop ) action='stop';;
    start ) action='start';;
    restart ) action='restart';;
    help ) action='help';;
    -i | --installdir )
      shift
      INSTALL_DIR=$1;;
    -f | --force ) prompt=0;;
    -h | --help )
      display_usage
      exit 0;;
    * )
      display_usage
      exit 1;;
  esac
  shift
done

if [ "${action}" = "restart" ]
then
  if ! restart_if_running
  then
    echo "Error restarting OoklaServer"
    exit 1
  fi
fi

if [ "${action}" = "start" ]
then
  if ! start_if_not_running
  then
    echo "Error starting OoklaServer"
    exit 1
  fi
fi

if [ "${action}" = "stop" ]
then
  if ! stop_if_running
  then
    echo "Error stopping OoklaServer"
    exit 1
  fi
fi

if [ "${action}" = "help" ]
then
  display_usage
  exit 0
fi

if [ "${action}" = "install" ]
then
  if ! detect_platform
  then
    echo "Error detecting platform, please check compatibility and try again."
    exit 1
  fi
  if [ "${prompt}" = "1" ]
  then
    if ! confirm_install
    then
      exit 1
    fi
  fi

  if ! goto_speedtest_folder
  then
    echo "Unable to use given Install Directory, please check your input and try again."
    exit 1
  fi

  if ! download_install
  then
    echo "Failed to download and install OoklaServer"
    exit 1
  fi

  if ! restart_if_running
  then
    echo "Error occurred (re)starting the OoklaServer"
    exit 1
  fi

  printf "NOTE\n\nWe strongly recommend following instructions at\n\n  "
  printf "https://support.ookla.com/hc/en-us/articles/234578588-Linux-Startup-Script-Options"
  printf "\n\nto ensure your daemon starts automatically when the system reboots\n"
fi
exit 0