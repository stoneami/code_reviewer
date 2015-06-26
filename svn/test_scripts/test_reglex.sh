content="- a-bc ddd"

if [[ "$content" == "-*" ]];
then
	a=1
#	echo "match"
else
	a=0
#	echo "unmatch"
fi

#set -x
#FILTER_KEY_WORDS="svn merge|update strings|词条库|导词条"
#grep -E "$FILTER_KEY_WORDS" log2.txt 
#set +x

DEBUG=1
function print_log(){
	if [ "$DEBUG" != "1" ]
	then
		return 0
	fi
	
	for l in "$@"
	do
		echo $l
	done
}

FILTER_KEY_WORDS="svn merge|update strings|词条库|导词条"
function need_check(){
	new_svn=$1	
	old_svn=$2
	
	start_line=5
	end_line=8
	
	LOG_FILE=log2.txt
	title_line=$((start_line+1))
#	content=$(sed -n ${start_line},${end_line}p $LOG_FILE )
	printf "LOG_FILE=$LOG_FILE\nstart_line=$start_line end_line=$end_line\nFILTER_KEY_WORDS=$FILTER_KEY_WORDS\n"
	ignore=$(sed -n ${start_line},${end_line}p $LOG_FILE  | grep -E "$FILTER_KEY_WORDS")
	echo ignore=$ignore
#	ignore=$(echo $content | grep -E "$FILTER_KEY_WORDS")

}

info="hello, kitty"
print_log "you can say ${info}" "good" "hi"


#need_check

#grep -iE '_exp\.png$|_exp\.jpg$|_exp\.jpeg$|_exp\.jar|_exp\.so|_exp.a' log2.txt

a=1
str=string11
str2=string
if [ "$str" != "$str2" ];
then
	b=
#	echo "not equal"
else
	a=
#	echo "equal"
fi

printf "%% abc"


ij=0
while [ $ij -lt 10 ];
do
	min=$((ij/60))
	sec=$((ij%60))
	echo "${min} minutes, ${sec} seconds"
	ij=$((ij+1))
#	sleep 0.2
done

aa=aa
bb="bb"
cc="cc"
dd=

if [ -z "$aa" -o \
	 -z "$bb" -o \
	 -z "$cc" -o \
	 -z "$dd" ];
then
	echo "Something is wrong ???"
fi

percent=60
printf "the percent is %d%%\n" $((percent+5))

if [ $percent != 50 ];then
	echo "No No No"
else
	echo "Yes"
fi

function test_var(){
	local test_inside="inside: test string"
	echo "test_var(): test_inside=${test_inside}"
	echo "test_var(): test_outside=${test_outside}"
}

test_outside="outside test string"

test_var

echo "outside: test_inside=${test_inside}"
echo "outside: test_outside=${test_outside}"

echo "-----------------------------------------------------"
regular_exp="hu\.li|liulei|\
chenjun|\
lilei"
grep -En "${regular_exp}" log.txt


echo "-----------------------------------------------------"
echo "-----------------------------------------------------"
JAVA_TYPE=1
JAVA_ADDED_FILE=2
C_TYPE=3
C_ADDED_FILE=4
XML_TYPE=5
XML_ADDED_FILE=6
OTHER_TYPE=0
function get_source_file_type(){
	local path=$1	
	local type=${path##*\.}
	
	if [ "$type" == "java" ];
	then	
		return "$JAVA_TYPE"
	elif [  "$type" == "c" -o "$type" == "cpp" -o "$type" == "hpp" -o "$type" == "h" ]
	then
		return "$C_TYPE"
	elif [ "$type" == "xml" ]		
	then
		return "$XML_TYPE"
	else
		return "$OTHER_TYPE"
	fi
}

function is_added_source_file(){
#package com.oppo.widget;
#namespace WebCore {
#xml version="1.0" encoding="UTF-8
	local path=$1
	local diff_content=$2
	get_source_file_type "$1"
	
	case "$?" in
	"$JAVA_TYPE") 
		if [ "$(echo "$diff_content" | grep -m 1 -E 'package .*;')" ];
		then
			echo "JAVA added file"
			return "$JAVA_ADDED_FILE"
		fi
		;;
	"$C_TYPE") 
		if [ "$(echo "$diff_content" | grep -m 1 -E 'namespace .*{')" ];
		then
			echo "C added file"
			return "$C_ADDED_FILE"
		fi
		;;
	"$XML_TYPE") 
		if [ "$(echo "$diff_content" | grep -m 1 -E 'xml version=.1.0. encoding=.UTF-8')" ];
		then
			echo "XML added file"
			return "$XML_ADDED_FILE"
		fi
		;;
	*) 
		return 0
	   ;;
	esac
}

is_added_source_file "/data/work/jb/rom/oppo/personal/backupandrestore/src/com/oppo/backup/Backup.java" "package com.oppo.widget;abc"
is_added_source_file "/data/work/jb/rom/oppo/personal/backupandrestore/src/com/oppo/backup/Backup.xml" "xml version=\"1.0\" encoding=\"UTF-8\""
is_added_source_file "/data/work/jb/rom/oppo/personal/backupandrestore/src/com/oppo/backup/Backup.c" "namespace WebCore {"
is_added_source_file "/data/work/jb/rom/oppo/personal/backupandrestore/src/com/oppo/backup/Backup.hpp" "namespace WebCore {"
is_added_source_file "/data/work/jb/rom/oppo/personal/backupandrestore/src/com/oppo/backup/Backup.cpp" "namespace WebCore {"
is_added_source_file "/data/work/jb/rom/oppo/personal/backupandrestore/src/com/oppo/backup/Backup.png" "aa"