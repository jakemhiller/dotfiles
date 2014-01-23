#!/bin/bash

#
# This script will turn ON AirPort only if it was turned OFF before
# by this script.
# If AirPort was turned off manually, it will not be automatically enabled
#

AIRPORT=""
ALLINTERFACES=""

beacon=/var/log/AirPortBeacon.beacon

IFS='
'

SW_VER=`/usr/bin/sw_vers -productVersion`

if [ `echo "if(${SW_VER%.*}>=10.7)r=1;r"|/usr/bin/bc` -eq 1 ];
then
   APNAME="Wi-Fi"
else
   APNAME="AirPort"
fi

#
# Look for AirPort interface and Create list of watched network interfaces
# We are looking for all Ethernet interfaces and Bluetooth PAN
#

for intf in `/usr/sbin/networksetup -listnetworkserviceorder | grep "^(H"`
do
   IFS=':,)'
   set $intf
   if [[ ($2 =~ Ethernet ) || ( $2 =~ "Bluetooth PAN" ) ]];
   then
      ALLINTERFACES="${ALLINTERFACES} $4";
   fi
   if [[ ($2 =~ ${APNAME} ) ]]; then AIRPORT=$4; fi
done

IFS='   
'

#
# If no interfaces to watch or no AirPort found - do nothing
#

if ( ([ -z "${ALLINTERFACES}" ]) || ([ -z ${AIRPORT} ]) );
then
  exit 0;
fi

#
# What software version we are running ?
# networksetup syntax changed in Snow Leopard
#

if [ `echo "if(${SW_VER%.*}>=10.6)r=1;r"|/usr/bin/bc` -eq 1 ];
then
   AP_CMD="/usr/sbin/networksetup -setairportpower ${AIRPORT}"
   AP_STATUS="/usr/sbin/networksetup -getairportpower ${AIRPORT}"
else
   AP_CMD="/usr/sbin/networksetup -setairportpower"
   AP_STATUS="/usr/sbin/networksetup -getairportpower"
fi

ap_state=`${AP_STATUS}`

#
# Check if watched interface have IP address assigned
# or (as an alternative - check if the interface is connected or not)
#

for ethintf in ${ALLINTERFACES}
do

   # Check if IPv4 address is assigned
   # 
   # ifconfig ${ethintf} 2>/dev/null | grep "inet " > /dev/null

   #
   # Check if interface is active
   #
   ifconfig ${ethintf} 2>/dev/null | grep "status: active" > /dev/null

   assigned=$?

   if [ $assigned -eq 0 ];
   then
      if [ "${ap_state##* }" == "On" ];
      then
  if [ ! -f ${beacon} ];
  then
           ${AP_CMD} off
  fi
         touch ${beacon}
      fi
      exit 0
   fi
done

if [ -f ${beacon} ];
then
  if [ "${ap_state##* }" == "Off" ];
  then
    ${AP_CMD} on
  fi
    rm ${beacon}
fi
exit 0