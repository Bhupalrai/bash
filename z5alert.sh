#!/bin/bash
#######################################################################
#               Z5 Alerting Tool
#----------------------------------------------------------------------
# Author          : Bhupal Rai
# Release version : 1.0.0
# Updated by      : Bhupal Rai
# Last updated    : 5 NOV 2017
# This tool is designed to monitor and alert whenever any issue
# is encountered in any of our component
#######################################################################
PRODAPP_ZAKIURL="https://mywebsite.com"

BASE_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/ && pwd)"
LOG_DIR="${BASE_DIR}/log"
TMP_DIR="${BASE_DIR}/tmp"
LOGFILE="${LOG_DIR}/z5alert.log"
MAILFILE="${TMP_DIR}/z5alert_mail.txt"
SECUREFILE="${TMP_DIR}/.secure.dat" # hex
MAIL_THRESHOLD="3"
SENTMAIL_COUNTFILE="${TMP_DIR}/.z5alert_sentmail.dat"
#
# No modify zone from here
COMPONENTS=(prod_app resource)
#######################################################################
# Functions
#######################################################################
function log(){
	logmsg=${1}
	logmsg=$(echo `date '+%Y-%m-%d %H:%M:%S'`" ${logmsg}")
	echo ${logmsg}
	echo ${logmsg} >> ${LOGFILE}
}

function exit0(){
	exit 0
}

function exit1(){
	exit 1
}

function usage_exit0(){
	usage
	exit0
}

function usage_exit1(){
	usage
	exit1
}

function syntxerr_usage_exit1(){
	echo -e "Syntax error occurred !"
	usage_exit1
}

function usage(){
echo "
 NAME:
  $0

 USAGE:
  bash $0 -h|--help
  bash $0

 DESCRIPTION:
  Z5 infrastructure monitoring and alerting tool

 PARAMETERS:
  -h|--help                     : show help

 EXAMPLES:
  bash $0 --help
"
}

function parse_opts {
	#
	#  Parse arguments
	#
	params=( "$@" )
	# usage
	# <code here>
}

function get_sentmailcount(){
  #
  # Send email notification
  # Globals:
  #   SECUREFILE
  # Arguments:
  #   mail_subject
  # Returns:
  #   Mail sent count for current incident
  key=${1}
  #for cmp in  "${COMPONENTS[@]}"; do
  cmp_val=$(cat ${SENTMAIL_COUNTFILE} |grep ${key} |cut -d'=' -f2 |head -n 1)
  if [ -z "${cmp_val}" ]; then
    # do not send mail when empty
    log "Warning! got empty value while reading status file. Adding entry with value greater than threshold"
    oc=$((MAIL_THRESHOLD + 1))
    echo "${key}=${oc}" >> ${SENTMAIL_COUNTFILE}
    echo "${oc}"
  fi
  echo "${cmp_val}"
  #done
}

function increase_sentmailcount(){
  key=${1}
  cur_val=$(cat ${SENTMAIL_COUNTFILE} |grep ${key} |cut -d'=' -f2 |head -n 1)
  cur_val=$((cur_val + 1))
  sed -i '/^#/!s|.*'"${key}"'.*|'"${key}=${cur_val}"'|g' ${SENTMAIL_COUNTFILE}
}

function send_mail(){
  #
  # Send email notification
  # Globals:
  #   SECUREFILE
  # Arguments:
  #   mail_subject
  # Returns:
  #   Boolean 0 for success, 1 for fail
  smpt_adr="smtp.gmail.com"
  port_num="465"
  username="z5msg@zakipoint.com"
  if [ ! -f "${SECUREFILE}" ]; then
    log "Secure file not found. Search path: ${SECUREFILE}"
    return 1
  fi
  hx_val=$(cat ${SECUREFILE} 2>/dev/null) # hide error
  if [ -z "${hx_val}" ]; then
    log "Error reading secure file for password. Search path ${SECUREFILE}"
    return 1
  fi
  # decode camouflaged
  password=$(python -c "print '${hx_val}'.decode('hex')")
  mail_subject="${1}"
  python sendmail.py "${smpt_adr}" "${port_num}" "${username}" "${password}" "${MAILFILE}" "${mail_subject}"
  return 0
}

function app_status(){
  # suppress SSL Certificate verification
  curl -s -k --connect-timeout 60 --max-time 180 -o "/dev/null" "${PRODAPP_ZAKIURL}"
  rc=$?
  if [ ${rc} -eq 0 ] ; then
    log "App is responding, OK"
    #
    # notify if app was unreachable last time
    last_count=$(cat ${SENTMAIL_COUNTFILE} | grep ${COMPONENTS[0]} |cut -d'=' -f2)
    if [ ${last_count} -gt 0 ]; then
      echo "Application is now reachable" > ${MAILFILE}
      echo "App URL ${PRODAPP_ZAKIURL}" >> ${MAILFILE}
      send_mail "[OK] APP is running"
    fi
    # reset sentmail
    rs_entry="${COMPONENTS[0]}=0"
    sed -i '/^#/!s|.*'"${COMPONENTS[0]}"'.*|'"${rs_entry}"'|g' ${SENTMAIL_COUNTFILE}
    return 0
  elif [ ${rc} -eq 6 ] ; then
    log "Unable to resolve host"
    log "Sending notification"
    echo "Application is not resolved" > ${MAILFILE}
    echo "App URL ${PRODAPP_ZAKIURL}" >> ${MAILFILE}
    echo "Please investigate as soon as possible" >> ${MAILFILE}
    if [ "$(get_sentmailcount "${COMPONENTS[0]}")" -lt ${MAIL_THRESHOLD} ]; then
      if ! send_mail "Alert [Unable to resolve host]"; then
        log "Error sending mail"
      fi
      increase_sentmailcount "${COMPONENTS[0]}"
    else
      log "Cannot send mail. Reached mail count threshold with value ${MAIL_THRESHOLD}"
    fi
    return 1
  elif [ ${rc} -eq 7 ] ; then
    log "Unable to connect to host"
    log "Sending notification"
    echo "Application is not reachable" > ${MAILFILE}
    echo "App URL ${PRODAPP_ZAKIURL}" >> ${MAILFILE}
    echo "Please investigate as soon as possible" >> ${MAILFILE}
    if [ $(get_sentmailcount "${COMPONENTS[0]}") -lt ${MAIL_THRESHOLD} ]; then
      if ! send_mail "Alert [Unable to connect to host]"; then
        log "Error sending mail"
      fi
      increase_sentmailcount "${COMPONENTS[0]}"
    else
      log "Cannot send mail. Reached mail count threshold with value ${MAIL_THRESHOLD}"
    fi
    return 1
  fi
  # app running
  return 0
}

function resource_usage(){
  #
  # Check for resource usage and notify if system is stressed
  # Globals:
  #   SECUREFILE
  # Arguments:
  #   mail_subject
  # Returns:
  #   Boolean 0 for success, 1 for fail
  return 0
}

function initialize(){
  mkdir -p ${LOG_DIR} && touch ${LOGFILE}
  mkdir -p ${TMP_DIR} && touch ${MAILFILE}
  [ ! -f ${LOGFILE} ] || [ ! -f ${MAILFILE} ] && {
    echo "Error creating required files"
    echo "Please verify file paths and permissions are valid and set properly"
    return 1
  }
  touch ${SENTMAIL_COUNTFILE}
  # add entry if doesn't exists
  for cmp in  "${COMPONENTS[@]}"; do
    if [ "$(cat ${SENTMAIL_COUNTFILE} | grep ${cmp} | wc -l )" -eq 0 ]; then
      echo "${cmp}=0" >> ${SENTMAIL_COUNTFILE}
    fi
  done
  return 0
}

function main {
  #parse_opts
  #
  # initialize, exit if fails
  if ! initialize; then
    exit1
  fi
  app_status
  resource_usage
}
main "$@"
