#!/bin/bash
#
PATH="${PATH}:/usr/local/bin"
HOME="/var/www"
#
source easybashweb
#
if [ "${step}" = "0" ]
	then
	next_step 1
	web_message "This is a \n web_message"
fi

if [ "${step}" = "1" ]
	then
	next_step 2
	web_preformatted_message "This is a \n web_preformatted_message"
fi

if [ "${step}" = "2" ]
	then
	next_step 3
	cat ${HOME}/Simple-Man_Lynyrd-Skynyrd.txt | web_text -c "blue,lightgrey"
fi

if [ "${step}" = "3" ]
	then
	next_step 4
	web_question "Do you like this question?"
fi

if [ "${step}" = "4" ]
	then
	next_step 5
	web_input 3    text "Username" "root"   text "IP address" "192.168.0.1"   text "Destination directory" "/tmp"
fi

if [ "${step}" = "5" ]
	then
	next_step 6
	web_menu "Heavy metal" "Rock and Roll" "Country" "Blues" "Pop" "Folk" "Classical"
fi

if [ "${step}" = "6" ]
	then
	next_step 7
	web_list +"Heavy metal" -"Rock and Roll" +"Country" +"Blues" -"Pop" -"Folk" +"Classical"
fi

if [ "${step}" = "7" ]
	then
	next_step 8
	web_fselect -c "purple,#90EE90"
fi

if [ "${step}" = "8" ]
	then
	next_step 9
	web_wait_for "Please wait..."
fi

if [ "${step}" = "9" ]
	then
	next_step 10
	web_adjust "Please, set Volume level" "15" "40" "75"
fi

if [ "${step}" = "10" ]
	then
	next_step 11
	web_itable -c "blue,white" -C "black,yellow" -T "My very nice table... (without \"-l\" arg)" -N 3 "1 person" "2 person" "3 person" "I" "NULL" "he/she" "we" "you" "they"
fi

if [ "${step}" = "11" ]
	then
	next_step 12
	web_itable -l -c "blue,white" -C "black,yellow" -T "My very nice table... (with \"-l\" arg)" -N 3 "1 person" "2 person" "3 person" "I" "NULL" "he/she" "we" "you" "they"
fi

if [ "${step}" = "12" ]
	then
	next_step 13
	web_tables -c "black,darkkhaki" -C "green,white" \
	-T "Table 1,Table 2" \
	-N 3,4 \
	"Table 1" "COL 1" "COL 2" "COL 3" "NULL" "lui" "lei" "Table 2" "COL 1" "COL 2" "COL 3" "COL 4" "aaa" "NULL" "bbb" "ccc" "ddd" "eee" 
fi

if [ "${step}" = "13" ]
	then
	next_step END
	web_final_message "www.yahoo.com" "Bye bye!"
fi


 
  
 