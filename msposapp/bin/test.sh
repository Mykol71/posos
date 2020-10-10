# gather user input
INPUTS="LOCATION_NAME STORE_PUBLIC STORE_NET PRESHAREDKEY"
POS_CLOUD_PUBLIC=`wget -qO- http://ipv4.icanhazip.com`
SHOPCODE=`cat .shopcode`

echo "Gathering required information...."
for var in $INPUTS; do
  echo -n "Enter $var: "
  read REPLY
  export $var=$REPLY
echo $REPLY
env | grep $var
done

