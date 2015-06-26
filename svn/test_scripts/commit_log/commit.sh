#!/bin/bash

function fn_analyze_svn_commit_log(){
	local svn_rev=$1
	
	LOG_FILE=svn_log.txt

	#Obtain specified svn log{
	local svn_log_total_line=$(wc -l $LOG_FILE | awk '{print $1}')
	local svn_log_start=$(grep -En "^r${svn_rev}" $LOG_FILE | awk -F ":" '{print $1}')
	local svn_log_end=$((svn_log_start+1))
	local i=$((svn_log_start+1))
	while(($i<=$svn_log_total_line))
	do
		local line=$(sed -n ${i}p $LOG_FILE | grep -E '\<r[0-9]+')
		if [ -z "$line" ];
		then
			i=$((i+1))
		else
			svn_log_end=$((i-1))
			break
		fi
	done

	if [ $i -gt $svn_log_total_line ];
	then
		svn_log_end=$svn_log_total_line
	fi
	#}
	
	local content=$(sed -n ${svn_log_start},${svn_log_end}p $LOG_FILE)
	local risk_line=$(echo "$content" | grep "$SVN_LOG_RISK_KEYWORD")
	
	fn_is_risk_correct "$risk_line"
	if [ $? -eq 1 ];
	then
		printf "${content}\n\n" >> bad_svn_log.sh
	fi
}

SVN_LOG_RISK_KEYWORD="risk"
SVN_LOG_BAD_RISK_CONTENT="none"
function fn_is_risk_correct(){
	local risk_line=$1
	risk_line=${risk_line/$SVN_LOG_RISK_KEYWORD/}
	echo "risk_line: $risk_line"
	if [ "$(echo "$risk_line" | grep -E "^${SVN_LOG_BAD_RISK_CONTENT}")" ];
	then
		echo "bad risk"
		return 1
	else
		echo "correct risk"
		return 0
	fi
}

fn_analyze_svn_commit_log 16928

