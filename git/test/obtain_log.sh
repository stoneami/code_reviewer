#!/bin/bash

#"2014-10-31 06:00:00"
start_time=$1
end_time=$2
start_revision=$1
end_revision=$2

LOG_FILE=$(pwd)/log.txt

REVISION_RANGE=1
DATE_RANGE=2
UNKNOWN=0

REGEX_COMMIT_ID="^[a-zA-Z|0-9]+$"
REGEX_DATE="^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"

function check_option(){
#	local is_commit_id1=$(echo "$start_revision" | grep -E "$REGEX_COMMIT_ID")
#	local is_commit_id2=$(echo "$end_revision" | grep -E "$REGEX_COMMIT_ID")
#	if [ "$is_commit_id1" -a "$is_commit_id2" ];
#	then
#		echo "revision range"
#		return $REVISION_RANGE
#	fi
	
	local is_date1=$(echo "$start_time" | grep -E "$REGEX_DATE")
	local is_date2=$(echo "$end_time" | grep -E "$REGEX_DATE")
	if [ "$is_date1" -a "$is_date2" ];
	then
		echo "DATE range"
		return $DATE_RANGE	
	fi
	
	echo "UNKNOWN !?"
	return $UNKNOWN
}

function obtain_log(){
	rm -f ${LOG_FILE}
	
	local ret=0
	check_option
	
	if [  $? -eq $DATE_RANGE  ];
	then
		repo forall -c "pwd;git log -p --pretty=format:'%h|%an|%ci|%s' --since='${start_time}' --before='${end_time}' >> ${LOG_FILE};echo ' ' >> ${LOG_FILE}"
	else
		ret=1
		echo "Warning: Please spcify revision range !"
	fi
	
	return $ret
}

##################Let's begin#######################
#obtain_log

str="liu"
if [ "$str" = "liu" ]
then
	echo "equal..."
else
	echo "not equal..."
fi

if [ ! -d "liu/lei" ]
then
	echo "not exist"
else
	echo "exist"
fi
