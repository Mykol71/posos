#!/bin/bash

# 
# VPN_CLIENT.SH
# 
if [ $# != 1 ] ; then
	echo "Usage: (sudo) sh $0 {init|start|stop}" 
	exit 1;
fi

# get vars.
VPN_ADDR=99.14.105.148
IFACE=eth1

# get IP.
function getIP(){
	ip addr show $1 | grep "inet " | awk '{print $2}' | sed 's:/.*::'       
}

# get gateway IP.
function getGateWay(){
	ip route show default | awk '/default/ {print $3}'
}

# get VPN gateway IP
function getVPNGateWay(){
	ip route | grep -m 1 "$VPN_ADDR" | awk '{print $3}'
}

# set gateway address
GW_ADDR=$(getGateWay)  

function init(){
	cp /etc/strongswan/ipsec.conf /etc/.
	cp /etc/strongswan/ipsec.secrets /etc/.
}

function start(){
	systemctl start strongswan
#ip route add $VPN_ADDR via $GW_ADDR dev $IFACE
#ip route add default via $(getIP ppp0)
#ip route del default via $GW_ADDR
}

function stop(){
	systemctl stop strongswan
	
	VPN_GW=$(getVPNGateWay)
#ip route del $VPN_ADDR via $VPN_GW dev $IFACE
#ip route add default via $VPN_GW
}

$1
exit 0
