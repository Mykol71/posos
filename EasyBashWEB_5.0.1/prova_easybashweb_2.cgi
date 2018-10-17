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
	web_menu "CIAO" "RI-CIAO" "kqwefjklwekqffklqwjfklqjlwefgl"
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
	web_list +"CIAO" -"RI-CIAO" +"RI-RI-CIAO" -"kqwefjklwekqffklqwjfklqjlwefgl"
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
	web_question "Ti piace?"
fi

if [ "${step}" = "6" ]
	then
	answer="${exit_code}"
	if [ ${answer} -eq 0 ]
		then
		choice="Ok"
	elif [ ${answer} -eq 1 ]
		then
		choice="Cancel"
	fi
	#
	next_step 7
	web_message "Hai scelto: \n ${choice}"
fi

if [ "${step}" = "7" ]
	then
	next_step 8
	web_input 3 text "primo valore" 0 text valore_iniziale 100 text "valore finale" 200
fi

if [ "${step}" = "8" ]
	then
	array_choices=( $(cat "${dir_tmp}/${file_tmp}" ) )
	choice_1="${array_choices[0]}"
	choice_2="${array_choices[1]}"
	choice_3="${array_choices[2]}"
	#
	next_step 9
	web_adjust "Please adjust..." ${choice_1} ${choice_2} ${choice_3}
fi

if [ "${step}" = "9" ]
	then
	choices="$(cat "${dir_tmp}/${file_tmp}" )"
	#
	next_step 10
	web_message "Hai scelto: \n ${choices}"
fi

if [ "${step}" = "10" ]
	then
	next_step END
	web_final_message "https://10.25.178.132/mail/src/login.php" "CIAO!!!"
fi
