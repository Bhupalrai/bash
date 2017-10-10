#!/bin/bash
#
#@Author Bhupal Rai
#######################################################################
#                    Monitor raspberrypi board temperature
#----------------------------------------------------------------------
# Shutdown device whenever device overheats
#
#######################################################################

max_temp_tolrt=76
showin_std=false  #take action

if [ "${1}" = "d" ]; then
    showin_std=true
fi

#
# cpu temp celcius
cpu_temp_cmd=`cat /sys/class/thermal/thermal_zone0/temp`
cpu_temp="CPU TEMP : $((cpu_temp_cmd/1000)) 'c"

#
# device temp, celcius
dvtmpval=`vcgencmd measure_temp | cut -f 2 -d "="|cut -f 1 -d "'"`
device_temp="RPY TEMP : ${dvtmpval} 'C"

if $showin_std; then
    echo ${cpu_temp}
    echo ${device_temp}

    exit 0
fi

tmp=`echo ${dvtmpval} | cut -f1 -d "."`
r_up_dvtmpval=`expr $(echo ${tmp}) + 1`

if [ $( echo $r_up_dvtmpval ) -gt $( echo ${max_temp_tolrt}) ]; then
    # prevent device burning, poweroff
    /usr/bin/logger "Shutting down due to SoC temp ${r_up_dvtmpval}."
    /sbin/shutdown -h now
else
   /usr/bin/logger "Current temperature. RPY: ${r_up_dvtmpval}'C, CPU: $((cpu_temp_cmd/1000))'C"
fi

exit 0
