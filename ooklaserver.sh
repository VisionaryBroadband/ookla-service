#!/bin/bash
##################
# OoklaServer install and management script
# (C) 2024 Ookla
##################
# Last Update 2024-01-30

# Declare Shell color variables
RED='\033[0;31m'    # [ ${RED}FAILED${NC}  ]
GREEN='\033[0;32m'  # [   ${GREEN}OK${NC}    ]
YELLOW='\033[1;33m' # [ ${YELLOW}WARNING${NC} ]
CYAN='\033[0;36m'   # [  ${CYAN}INFO${NC}   ]
NC='\033[0m'        # No Color

BASE_DOWNLOAD_PATH="https://install.speedtest.net/ooklaserver/stable/"
DAEMON_FILE="OoklaServer"
INSTALL_DIR=''
PID_FILE="${DAEMON_FILE}.pid"
dir_full=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
LOG_DIR="/var/log/Ookla"
LOG_FILE="${LOG_DIR}/Ookla-Server.log"
DEBUG="false"

function setup_logging() {
  if ! sudo mkdir -p "${LOG_DIR}"
  then
    return 1
  else
    if ! chown -R "${USER}":"${USER}" "${LOG_DIR}"
    then
      return 1
    fi
    return 0
  fi
}

###
# Function to write to log file
# - $1 string Contains the status of the log entry
# - $2 string Contains the msg of the log entry
###
function log_write() {
  local timestamp
  timestamp=$(/usr/bin/date +"%b %d %H:%M:%S ooklaserver:")
  if [[ -z "${1}" ]] || [[ -z "${2}" ]]
  then
    echo "${timestamp} [ WARN ] status or msg was not sent in log_write function" >> "${LOG_FILE}"
    if [[ "${DEBUG}" == "true" ]]
    then
      echo -e "[ ${YELLOW}WARNING${NC} ] status or msg was not sent in log_write function"
    fi
    return 1
  else
    echo "${timestamp} [ ${1} ] ${2}" >> "${LOG_FILE}"
    if [[ "${DEBUG}" == "true" ]]
    then
      case "${1}" in
        INFO)
          echo -e "[  ${CYAN}INFO${NC}   ] ${2}";;
        CRIT)
          echo -e "[  ${RED}ERROR${NC}  ] ${2}";;
        WARN)
          echo -e "[ ${YELLOW}WARNING${NC} ] ${2}";;
        OKAY)
          echo -e "[   ${GREEN}OK${NC}    ] ${2}";;
        *)
          echo -e "[ ${1} ] ${2}";;
      esac
    fi
    return 0
  fi
}

###
# Function to show how to use this script and it's options and args
###
function display_usage() {
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
  echo  "  -d|--debug           Prints debuggin info to console"
  echo  ""
}

###
# Function to check if a command exists on the system or not
# - $1 string Contains the command to test
###
function has_command() {
  if ! type "$1" >/dev/null 2>&1
  then
    # Command doesn't exist, result in error
    return 1
  else
    # Command does exist, result in success
    return 0
  fi
}

###
# Function to determine what OS the script is being ran on
###
function detect_platform() {
  # detect operating system
  case $( uname -s ) in
  Darwin)
    server_package='macosx';;
  Linux)
    server_package='linux-aarch64-static-musl'
    arch=$(uname -m)
    if [[ "${arch}" = "x86_64" ]]
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
        log_write "WARN" "Invalid platform selection!"
        return 1;;
    esac
  esac

  log_write "INFO" "Server Platform is $server_package"
}

###
# Function confirm if the user actually wishes to install the OoklaServer on the OS
###
function confirm_install() {
  if [[ "${INSTALL_DIR}" != "" ]]
  then
    printf "%s" "This will install the Ookla server for $server_package to folder $INSTALL_DIR. Please confirm (y/n) > "
  else
    printf "%s" "This will install the Ookla server for $server_package to the current folder. Please confirm (y/n) > "
  fi
  read -r response
  if [[ "${response}" != "y" ]]
  then
    log_write "INFO" "Exiting program."
    return 1
  fi
}

###
# Function to change the working directory to the desired install directory
###
function goto_speedtest_folder() {
  # determine if base install folder exists
  local dir_base
  local scriptname
  dir_base=$(basename "${dir_full}")

  if [[ "${INSTALL_DIR}" != "" ]]
  then
    log_write "INFO" "Checking Directory Structure"
    if [[ "${dir_base}" != "${INSTALL_DIR}" ]]
    then
      if [[ ! -d "${INSTALL_DIR}" ]]
      then
        if ! mkdir -p "${INSTALL_DIR}"
        then
          log_write "WARN" "Failed to create the installation directory"
          return 1
        else
          # copy script to folder
          scriptname=$(basename "${0}")
          if ! cp "${scriptname}" "${INSTALL_DIR}"
          then
            log_write "WARN" "Failed to copy files into install directory"
            return 1
          fi
        fi
      fi
      cd "${INSTALL_DIR}" || log_write "WARN" "Failed install to ${INSTALL_DIR}" && return 1
    fi
  fi
}

###
# Function to download and install the OoklaServer files
###
function download_install() {
  local gzip_download_file
  local gzip_download_url
  local curl_path
  local wget_path
  local fetch_path

  # download the v3 server files with either wget or curl or fetch
  gzip_download_file="OoklaServer-${server_package}.tgz"
  gzip_download_url="${BASE_DOWNLOAD_PATH}${gzip_download_file}"

  curl_path=$(command -v curl)
  wget_path=$(command -v wget)
  fetch_path=$(command -v fetch)

  log_write "INFO" "Downloading Server Files"
  if [[ -n "${curl_path}" ]]
  then
    curl -O "${gzip_download_url}"
  elif [[ -n "${wget_path}" ]]
  then
    wget "${gzip_download_url}" -O "${gzip_download_file}"
  elif [[ -n "${fetch_path}" ]]
  then
    # fetch is found in base OS in FreeBSD
    fetch -o "${gzip_download_file}" "${gzip_download_url}"
  else
    log_write "WARN" "This script requires CURL or WGET or FETCH"
    return 1
  fi

  # extract package
  if [[ -f "${gzip_download_file}" ]]
  then
    log_write "INFO" "Extracting Server Files"
    if ! tar -zxovf "${gzip_download_file}"
    then
      log_write "WARN" "Failed to extract downloaded server files"
      return 1
    fi
    if ! rm "${gzip_download_file}"
    then
      log_write "WARN" "Failed to clean up downloaded compressed file"
      return 1
    fi
    if [[ ! -f "${DAEMON_FILE}.properties" ]]
    then
      if ! cp "${DAEMON_FILE}.properties.default" "${DAEMON_FILE}.properties"
      then
        log_write "WARN" "Failed to copy default properties to new file"
        return 1
      fi
    fi
  else
    log_write "WARN" "Error downloading server package"
    return 1
  fi

  # Deploy service unit and reload the daemon
  printf "Would you like to install this as a Service for start on boot functionality? Please confirm (y/n) > "
  read -r svcResponse
  if [[ "${svcResponse}" = "y" ]]
  then
    if ! cp "OoklaServer.service.example" "OoklaServer.service"
    then
      log_write "WARN" "Failed to create OoklaServer.service file from example, please check permissions and try again"
      return 1
    else
      if ! sudo chmod 664 "OoklaServer.service"
      then
        log_write "WARN" "Failed to apply permissions to OoklaServer.service file"
        return 1
      fi
    fi
    printf "You may be prompted for a sudo password next to make the symbolic link to /etc/systemd/ and to reload the systemctl-daemon\n"
    # Update the USER/GROUP in the service file
    if ! sed -i '/User= #/c\User='"${USER}" 'OoklaServer.service'
    then
      log_write "WARN" "Failed to set the user on OoklaServer.service, please set manually"
    fi
    if ! sed -i '/Group= #/c\Group='"${USER}" 'OoklaServer.service'
    then
      log_write "WARN" "Failed to set the group on OoklaServer.service, please set manually"
    fi
    if ! sed -i '/WorkingDirectory=/c\WorkingDirectory='"${dir_full}/" 'OoklaServer.service'
    then
      log_write "WARN" "Failed to set filepath on WorkingDirectory in OoklaServer.service, please set manually"
    fi
    if ! sed -i '/PIDFile=/c\PIDFile='"${dir_full}/OoklaServer.pid" 'OoklaServer.service'
    then
      log_write "WARN" "Failed to set filepath on PIDFile in OoklaServer.service, please set manually"
    fi
    if ! sed -i '/ExecStart=/c\ExecStart='"${dir_full}/ooklaserver.sh start" 'OoklaServer.service'
    then
      log_write "WARN" "Failed to set filepath on ExecStart cmd in OoklaServer.service, please set manually"
    fi
    if ! sed -i '/ExecReload=/c\ExecReload='"${dir_full}/ooklaserver.sh restart" 'OoklaServer.service'
    then
      log_write "WARN" "Failed to set filepath on ExecReload cmd in OoklaServer.service, please set manually"
    fi
    if ! sed -i '/ExecStop=/c\ExecStop='"${dir_full}/ooklaserver.sh stop" 'OoklaServer.service'
    then
      log_write "WARN" "Failed to set filepath on ExecStop cmd in OoklaServer.service, please set manually"
    fi
    # Create the Symbolic link
    if ! sudo ln -s "${dir_full}/OoklaServer.service" "/etc/systemd/system/OoklaServer.service"
    then
      log_write "WARN" "Failed to install OoklaServer service!"
      return 1
    fi
    # Reload the systemctl daemon
    if ! sudo systemctl daemon-reload
    then
      log_write "WARN" "Failed to reload the systemctl daemon"
      return 1
    fi
  fi
}

###
# Function to start the OoklaServer Daemon
###
function start() {
  local daemon_cmd
  local daemon_pid
  log_write "INFO" "Starting ${DAEMON_FILE}"
  # Check if the Daemon installed
  if [[ -f "${dir_full}/${DAEMON_FILE}" ]]
  then
    # Make the Daemon executable
    if ! chmod +x "${dir_full}/${DAEMON_FILE}"
    then
      log_write "WARN" "Failed to make ${DAEMON_FILE} executable"
      return 1
    fi
    # Specify the command to run the Daemon
    daemon_cmd="${dir_full}/${DAEMON_FILE} --daemon --pidfile=${dir_full}/${PID_FILE}"
    # Execute the command
    $daemon_cmd
  else
    log_write "WARN" "Daemon not installed. Please run install first."
    return 1
  fi

  # wait for PID file to be created and verify daemon started
  i=0
  while [[ "$i" -lt 10 ]]
  do
    sleep 1
    if [[ -f "${dir_full}/${PID_FILE}" ]]
    then
      break
    fi
    i=$((i+1))
  done

  # Check if the PID file was created and report its contents
  if [[ -f "${dir_full}/${PID_FILE}" ]]
  then
    daemon_pid=$(cat "${dir_full}/${PID_FILE}")
    log_write "OKAY" "Daemon Started (${daemon_pid})"
    return 0
  else
    log_write "WARN" "Failed to Start Daemon"
    return 1
  fi
}

###
# Function to terminate the OoklaServer Process
# - $1 string Contains the Process Group ID (PGID) of the OoklaServer Daemon that should be stopped
###
function stop_process() {
  local daemon_pgid
  daemon_pgid="${1}"
  log_write "INFO" "Stopping ${DAEMON_FILE} Daemon (${daemon_pgid})"
  # Send the SIGTERM signal to the Daemon to see if it will close and exit cleanly
  kill -- -${daemon_pgid} 2>/dev/null 1>&2

  # Check if the process was stopped every second for 10 seconds
  i=0
  while [[ "$i" -lt 10 ]]
  do
    if kill -0 -${daemon_pgid} 2>/dev/null 1>&2
    then
      # Process is still active, sleep and recheck
      sleep 1
    else
      # Process doesn't exist, move on
      break
    fi
    i=$((i+1))
  done

  # Check if the process was successfully stopped
  if kill -0 -${daemon_pgid} 2>/dev/null 1>&2
  then
    # Process failed to stop, send SIGKILL
    if (kill -9 -- -${daemon_pgid} 2>/dev/null 1>&2)
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

###
# Function to start the OoklaServer if it is not already running
###
function start_if_not_running() {
  local daemon_pid
  # Check if the Main PID file exists, if it does not, the daemon is likely not running
  if [[ -f "${dir_full}/${PID_FILE}" ]]
  then
    # Check if there is a Process ID stored within the PID_FILE
    daemon_pid=$(cat "${dir_full}/${PID_FILE}")
    if [[ -n "${daemon_pid}" ]]
    then
      # Check if there is an Active process with that PID
      if kill -0 "${daemon_pid}" > /dev/null 2>&1
      then
        log_write "WARN" "${DAEMON_FILE} (${daemon_pid}) is already running"
        return 0
      fi
    fi
  fi

  # OoklaServer is not already running, start it up
  if ! start
  then
    # The OoklaServer failed to start up, errors were already reported by the function(start)
    return 1
  fi
}

###
# Function to handle the restart of the OoklaServer
###
function restart_if_running() {
  if ! stop_if_running
  then
    return 1
  fi
  if ! start
  then
    return 1
  fi
}

###
# Function to stop the OoklaServer if it is running
###
function stop_if_running() {
  local daemon_pid
  local main_pgid
  local pids
  # Check if the Main PID file exists, if it does, the daemon is likely running
  if [[ -f "${dir_full}/${PID_FILE}" ]]
  then
    daemon_pid=$(cat "${dir_full}/${PID_FILE}")
    if [[ "${daemon_pid}" ]]
    then
      # Get the Process Group ID (PGID) to stop all processes in the forked hierarchy
      main_pgid=$(ps -o pgid= -p "${daemon_pid}" | grep -o '[0-9]*')
      # Verify a PGID was returned
      if [[ -n "${main_pgid}" ]]
      then
        if stop_process "${main_pgid}"
        then
          log_write "OKAY" "Successfully stopped OoklaServer"
          return 0
        else
          log_write "WARN" "Failed to stop OoklaServer"
          return 1
        fi
      else
        # Did not get a PGID, falling back to Process ID
        if has_command pgrep
        then
          pids=$(pgrep OoklaServer 2>&1 | sed -z 's/\n/ /g' | xargs)
          if [[ -n "${pids}" ]]
          then
            log_write "INFO" "Additional ${DAEMON_FILE} processes running; killing (${pids})"
            if (pgrep OoklaServer | xargs kill -9)
            then
              log_write "OKAY" "Successfully stopped OoklaServer"
              return 0
            else
              log_write "WARN" "Failed to stop OoklaServer"
              return 1
            fi
          else
            log_write "OKAY" "No OoklaServer processes found"
            return 0
          fi
        fi
      fi
    fi
  fi
}

##### Main

## Create log dir for script output and service logging
if [[ ! -d "${LOG_DIR}" ]]
then
  if ! setup_logging
  then
    echo -e "[  ${RED}ERROR${NC}  ] Could not create log directory"
    exit 1
  fi
fi

prompt=1
action='help'
while [[ "$1" != "" ]]
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
    -d | --debug ) DEBUG="true";;
    * )
      display_usage
      exit 1;;
  esac
  shift
done

if [[ "${action}" = "start" ]]
then
  if ! start_if_not_running
  then
    log_write "CRIT" "There was an Error starting OoklaServer"
    exit 1
  fi
fi

if [[ "${action}" = "restart" ]]
then
  if ! restart_if_running
  then
    log_write "CRIT" "There was an error restarting OoklaServer"
    exit 1
  fi
fi

if [[ "${action}" = "stop" ]]
then
  if ! stop_if_running
  then
    log_write "CRIT" "There was an Error stopping OoklaServer"
    exit 1
  fi
fi

if [[ "${action}" = "help" ]]
then
  display_usage
  exit 0
fi

if [[ "${action}" = "install" ]]
then
  if ! detect_platform
  then
    log_write "CRIT" "There was an Error detecting platform, please check compatibility and try again."
    exit 1
  fi
  if [[ "${prompt}" = "1" ]]
  then
    if ! confirm_install
    then
      exit 1
    fi
  fi

  if ! goto_speedtest_folder
  then
    log_write "CRIT" "Unable to use given Install Directory, please check your input and try again."
    exit 1
  fi

  if ! download_install
  then
    log_write "CRIT" "Failed to download and install OoklaServer"
    exit 1
  fi

  if ! restart_if_running
  then
    log_write "CRIT" "An error occurred (re)starting the OoklaServer"
    exit 1
  fi

  printf "NOTE\n\nWe strongly recommend following instructions at\n\n  "
  printf "https://support.ookla.com/hc/en-us/articles/234578588-Linux-Startup-Script-Options"
  printf "\n\nto ensure your daemon starts automatically when the system reboots\n"
  exit 0
fi
exit 0