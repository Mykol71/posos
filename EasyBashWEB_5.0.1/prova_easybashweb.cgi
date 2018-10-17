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
	web_message "CIAO INIZIALE"
fi

if [ "${step}" = "1" ]
	then
	next_step 2
	web_menu "CIAO" "RI-CIAO"
fi

if [ "${step}" = "2" ]
	then
	choices="$(cat "${dir_tmp}/${file_tmp}" )"
	#
	next_step 3
	web_message "Hai scelto: \n ${choices}"
fi

if [ "${step}" = "3" ]
	then
	next_step 4
	web_input 3 "text" "ciao" "ciao" "text" "ri-ciao" "NULL" "password" "ri-ri-ciao" "bua"
fi

if [ "${step}" = "4" ]
	then
	choices="$(cat "${dir_tmp}/${file_tmp}" )"
	#
	next_step 5
	web_message "Hai scelto: \n ${choices}"
fi

if [ "${step}" = "5" ]
	then
	next_step 6
	web_itable -c "red,white" -C "black,yellow" -N 3 "io" "te" "noi" "voi" "lui" "lei"
fi

if [ "${step}" = "6" ]
	then
	next_step 7
	web_itable -c "red,white" -C "black,yellow" -T "tabella di prova \n Vedi che bella cosa..." -N 3 "io" "te" "noi" "voi" "lui" "lei"
fi

if [ "${step}" = "7" ]
	then
	choices="$(cat "${dir_tmp}/${file_tmp}" )"
	#
	next_step 8
	web_message "Hai scelto: \n ${choices}"
fi

if [ "${step}" = "8" ]
	then
	next_step 9
	web_tables \
	-c "red,white" \
	-C "black,yellow" \
	-T "tabella di prova 1,tabella di prova 2,tabella di prova 3" \
	-N 3,2,4 \
	"tabella di prova 1" "io" "NULL" "noi" "NULL" "lui" "lei" "tabella di prova 2" "IO" "TE" "NOI" "VOI" "LUI" "tabella di prova 3" aaa bbb ccc ddd eee fff ggg hhh iii lll mmm NULL
fi

if [ "${step}" = "9" ]
	then
	next_step 10
	web_tables \
	-c "red,white" \
	-C "black,yellow" \
	-N 3,2,4 \
	"tabella di prova 1" "io" "NULL" "noi" "NULL" "lui" "lei" "tabella di prova 2" "IO" "TE" "NOI" "VOI" "LUI" "tabella di prova 3" aaa bbb ccc ddd eee fff ggg hhh iii lll mmm NULL
fi

if [ "${step}" = "10" ]
	then
	next_step 11
	web_tables \
	-c "red,white" \
	-C "black,yellow" \
	-N 2 \
	"tabella di prova 1" "io" "NULL" "noi" "NULL" "lui" "lei" "tabella di prova 2" "IO" "TE" "NOI" "VOI" "LUI" "tabella di prova 3" aaa bbb ccc ddd eee fff ggg hhh iii lll mmm NULL
fi

if [ "${step}" = "11" ]
	then
	next_step END
	web_final_message "https://10.25.178.132/mail/src/login.php" "CIAO!!!"
fi
