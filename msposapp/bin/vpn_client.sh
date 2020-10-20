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
	cp ./ipsec.conf /etc/strongswan/strongswan.d/charon/.
	cp ./ipsec.secrets /etc/
}

function start(){
#sed -i "s/^lns =.*/lns = $VPN_ADDR/g" /etc/xl2tpd/xl2tpd.conf
#sed -i "s/plutoopts=.*/plutoopts=\"--interface=$IFACE\"/g" /etc/ipsec.conf
#sed -i "s/left=.*$/left=$(getIP $IFACE)/g" /etc/ipsec.conf
#sed -i "s/right=.*$/right=$VPN_ADDR/g" /etc/ipsec.conf
#sed -i "s/^.*: PSK/$(getIP $IFACE) $VPN_ADDR : PSK/g" /etc/ipsec.secrets
	systemctl start strongswan
	sleep 2    #delay to ensure that IPsec is started before overlaying L2TP

	ipsec auto --up L2TP-PSK                        
#echo "c vpn-connection" > /var/run/xl2tpd/l2tp-control     
	sleep 2    #delay again to make that the PPP connection is up.

#ip route add $VPN_ADDR via $GW_ADDR dev $IFACE
#ip route add default via $(getIP ppp0)
#ip route del default via $GW_ADDR
}

function stop(){
#ipsec auto --down L2TP-PSK
#echo "d vpn-connection" > /var/run/xl2tpd/l2tp-control
	systemctl stop strongswan
	
	VPN_GW=$(getVPNGateWay)
#ip route del $VPN_ADDR via $VPN_GW dev $IFACE
#ip route add default via $VPN_GW
}

$1
exit 0
