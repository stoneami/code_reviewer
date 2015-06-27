#!/bin/bash

# -------------------------------------------------------------------------------
# Filename:    submit_checker.sh
# Revision:    2.0
# Date:        2014/10/31
# Author:      Jerry
# Email:       liulei@oppo.com
# Description: Check the git submitting     
# -------------------------------------------------------------------------------

function main(){
	check_option
	
	if [ $? -eq $UNKNOWN ];
	then
		print_usage
#		return 0
	fi

#	obtain_log
	
	analyze_git
	
	print_elapsed_time "$RUN_TIME"
}

function init() {
	echo "init()"
}

function print_elapsed_time(){
	local start=$1
	
	local end=$(date +%s)
	local total_seconds=$((end-start+1))
	if [ $total_seconds -lt 60 ];
	then
		ret="${total_seconds} seconds"
	else
		min=$((total_seconds/60))
		sec=$((total_seconds%60))
		ret="${min} minutes, ${sec} seconds"
	fi
	printf "\nCongratulations! \nTotal time: ${ret}\n"
}

function check_option(){
	local date_start=$(echo "$GIT_START_TIME" | grep -E "$REGEX_DATE")
	local date_end=$(echo "$GIT_END_TIME" | grep -E "$REGEX_DATE")
	if [ "$date_start" -a "$date_end" ];
	then
		return $DATE_RANGE
	fi
	
	return $UNKNOWN
}

function obtain_log(){
	rm -rf $OUT_DIR
	mkdir -m 777 -p "${TEMP_DIR}"
	
	local ret=0
	check_option
	
	if [  $? -eq $DATE_RANGE  ];
	then
		repo forall -c "echo -n '${DB_MARK}' >> ${LOG_FILE};pwd >> ${LOG_FILE};git log -p --pretty=format:'%h|%an|%ci|%s' --since='${GIT_START_TIME}' --before='${GIT_END_TIME}' >> ${LOG_FILE};echo '' >> ${LOG_FILE}"
		cp ${LOG_FILE} log_backup.txt
		#remove blank line
		sed -ri '/^[ \t]*$|^[-+]$/d' ${LOG_FILE}
		grep -En "^${DB_MARK}" ${LOG_FILE} > ${DB_LIST_FILE}
	else
		ret=1
		echo "Please specify revision range !"
	fi
	
	return $ret
}

DB_AMOUNT=0
INTERVAL=0.5
MAX_THREAD=1

function analyze_git(){
	DB_AMOUNT=$(wc -l $DB_LIST_FILE | awk '{print $1}')	
	
	if [ $DB_AMOUNT -lt 1 ]
	then
		echo "No git database found !"
		return 0
	fi
	
	echo "analyze_git total: ${DB_AMOUNT}"
	
	local i=1
	local j=1
	while((i<=DB_AMOUNT))
	do

		for((j=1; j<=MAX_THREAD && i<=DB_AMOUNT; j++,i++))
		do
			analyze_per_git $i &
		done
		
		wait

		sleep $INTERVAL
	done
	
}

#config for multi-commit in a git
INTERVAL_COMMIT=0.1
MAX_THREAD_COMMIT=8

#The commit begins with "98fbd8c|" or "a3fb33c|" ...
REGEX_COMMIT="^([a-zA-Z0-9]+)(\|)"

function analyze_per_git(){
	#git index in $DB_LIST_FILE
	local git_index="$1"
	
	get_git_range "$git_index"
	local range=$?

	if((range==0))
	then
		echo "^-^ no change in $(get_git_name $git_index)"
		return 0
	else
		echo "analyze_per_git: analyzing git $(get_git_name $git_index)"
	fi
	
	#git content range from $start to $end
	local start=$(sed -n ${git_index}p $DB_LIST_FILE | awk -F ":" '{print $1}' )
	local end=$((start+range))
	
	#like this
	###Database###:/home/stoneami/work/some_code/msm8939_14061/MSM8939_LA_1_0_20_3/android/emmc_img_4d3
	#diff --git a/android_webview/native/aw_settings.cc b/android_webview/native/aw_settings.cc
	#index d5d60ba..6bf8e22 100755
	#--- a/android_webview/native/aw_settings.cc
	#+++ b/android_webview/native/aw_settings.cc
	#...
	#diff --git a/dynamic_nvbk.bin b/dynamic_nvbk.bin
	#index c6db55f..e38ad92 100755
	#Binary files a/static_nvbk.bin and b/static_nvbk.bin differ
	#6a35d46|liulei|2014-11-07 16:02:00 +0800|[14061&14065&14085]AirService:外销14061&14065&14085 打开Disable APN Name Matching功能 分析：外销14061&14065&14085 打开Disable APN Name Matching功能 方案：外销14061&14065&14085 打开Disable APN Name Matching功能 风险：代码无风险 提交类型：other 影响范围：LTE ps域 测试建议：不需要 自测用例路径：Export\开发交付自测用例文档_Default.xlsx
	#diff --git a/dynamic_nvbk.bin b/dynamic_nvbk.bin
	#index 1eb6d9f..c6db55f 100755
	#...
	local one_git=$(sed -n ${start},${end}p $LOG_FILE)

	#like this:
	#6:11b54a6|liulei|2014-11-06 20:45:37
	#26:301e912|lilei|2014-11-08 05:14:45
	#30:531e912|zhouyu|2014-11-08 05:30:12
	local commit_list=$(echo "$one_git" | grep -En "$REGEX_COMMIT")
	
#	echo "------------------------one_git----------------------------"
#	echo "one_git：(${start},${end}) $one_git"
#	echo "------------------------one_git-------------------------"
	
#	echo "-----------------------------------------------------------"
#	echo "commit_list： $commit_list"
#	echo "-----------------------------------------------------------"
	local commit_amount=$(echo "$commit_list" | wc -l)
	echo "analyze_per_git commit_amount=$commit_amount"
	
	local i=1
	local j=1
	while((i<=commit_amount))
	do
		for((j=1; j<=MAX_THREAD_COMMIT && i<=commit_amount; j++, i++))
		do
			echo "i=$i j=$j"
			analyze_per_commit "$one_git" "$commit_list" "$i" "$git_index" &
		done
		
		wait

		sleep $INTERVAL_COMMIT
	done
}

# $1 is the line of git in $DB_LIST_FILE
function get_git_name(){
	#git index in $DB_LIST_FILE
	local idx="$1"
	local local_path=$(sed -n ${idx}p $DB_LIST_FILE | awk -F ":" '{print $3}' )
	local git_name=${local_path#$CUR_DIR/}
	echo "$git_name"
}

REGEX_DIFF='diff --git'
function analyze_per_commit(){
	local one_git="$1"

	#all commits titles in one git
	local commit_list="$2"
	
	#the commit index in $commit_list
	local commit_i="$3"
	
	#git name
	local git_index=$4
	local git_name=$(get_git_name "$git_index" | sed -r 's:/:-:g')

	#range of one commit {
	local commit_amount=$(echo "$commit_list" | wc -l)
	local start=$(echo "$commit_list" | sed -n ${commit_i}p | awk -F ":" '{print $1}')

	local end=0
	if((commit_i<commit_amount))
	then
		end=$(echo "$commit_list" | sed -n $((commit_i+1))p | awk -F ":" '{print $1}')
		end=$((end-1))
	else
		end=$(echo "$one_git" | wc -l)
	fi
	#}
	
	#NO content ? {
	if((end<=start))
	then
		echo "NOTHING for $(echo "$commit_list" | sed -n ${commit_i}p) !"
#		echo "analyze_per_commit commit_cur=$commit_i quit"
		return 0
	else
		echo "analyze_per_commit commit_i=${commit_i} commit_amount={$commit_amount} (${start},${end})"
	fi
	#}
	
	#one commit content
	local one_commit=$(echo "$one_git" | sed -n ${start},${end}p)
	local diff_list=$(echo "$one_commit" | grep -En "$REGEX_DIFF")
	local diff_amount=$(echo "$diff_list" | wc -l)
	
	#analyze commit log
	local commit_log=$(echo "$one_commit" | sed -n 1p)
	analyze_commit_log "$commit_log"
	local log_ret=$?
	#
	#save the invalid commit log
	#
	
	#
	#set the log file name
	#like liulei_2014-11-14_aa39bc6
	#56d8245|guoling|2014-11-14 17:55:27 +0800|[14037] 解决14037
	#
	local author=$(echo "$commit_log" | awk -F "|" '{print $2}' | sed -r 's/ //g')
	local commit_id=$(echo "$commit_log" | awk -F "|" '{print $1}')
	local commit_date=$(echo "$commit_log" | awk -F "|" '{print $3}' | awk '{print $1}')

	local invalid_log_file="${author}_${commit_date}_${commit_id}.log"
	
	#analyze every modified file
	local diff_i=1
	while((diff_i<=diff_amount))
	do
		local diff_start=$(echo "$diff_list" | sed -n ${diff_i}p | awk -F ":" '{print $1}')
		if((diff_i<diff_amount))
		then			
			local diff_end=$(echo "$diff_list" | sed -n $((diff_i+1))p | awk -F ":" '{print $1}')
			diff_end=$((diff_end-1))
		else
			local diff_end=$(echo "$one_commit" | wc -l)
		fi
		
		echo "analyze_per_commit commit_cur=$commit_i diff_amount=$diff_amount diff_i=$diff_i (${diff_start},${diff_end})"
		
		local diff_content=$(echo "$one_commit" | sed -n ${diff_start},${diff_end}p)
		
		local diff_name=$(echo "$diff_content" | head -n 1)
		if [ "$(echo "$diff_content" | wc -l)" -lt 3 ]
		then
			echo "Nothing for \"${diff_name}\" ?"
			diff_i=$((diff_i+1))
			continue
		fi
		
		analyze_diff "$diff_content"
		local ret=$?
		
		#
		#save the result in files
		#
		save_diff_analyze_result "$git_name" "$commit_log" "$ret" "$invalid_log_file" "$diff_content"
		
		diff_i=$((diff_i+1))
	done
	echo "analyze_per_commit commit_cur=$commit_i quit"
}

DETAIL_UNKNOWN=">>>Unkonwn reason (Binary type ?)"
DETAIL_INCORECT_HEAD_ANNOTATION=">>>REASON: no (or incorrect) head annotation"
DETAIL_NO_ANNOTATION=">>>REASON: no annotation"
DETAIL_VENDOR_EDIT_UNMATCHED=">>>REASON: part of modification without annotation"
DETAIL_ADDED_FILE_WITHOUT_EXP=">>>REASON: added (or modified) file without '_exp' "
function save_diff_analyze_result(){
	local git_name=$1
	local commit_log=$2
	local analyze_ret=$3
	local file=$4
	local diff=$5
	
	#
	#everything is ok
	#
	if [ "$analyze_ret" -eq "$DIFF_PASS" ]
	then
		return 0
	fi
	
	#
	#something goes wrong
	#
	local target_dir="${OUT_DIR}/${git_name}"
	if [ ! -d "$target_dir" ];then
		mkdir -m 777 -p "${target_dir}"
	fi
	
	#
	#create the invalid log file for the first time. And write the commit log into it
	#
	local log_file="${target_dir}/${file}"
	echo "log_file: ${log_file}"
	if [ ! -f "$log_file" ]
	then
		printf "${commit_log}\n\n" >> $log_file
	fi
	
#	echo " " >> $log_file
	
	case "$analyze_ret" in
	"$REASON_ADDED_FILE_WITHOUT_EXP")
		echo "$DETAIL_ADDED_FILE_WITHOUT_EXP" >> $log_file
	;;	
	"$REASON_VENDOR_EDIT_UNMATCHED")
		echo "$DETAIL_VENDOR_EDIT_UNMATCHED" >> $log_file
	;;	
	"$REASON_NO_ANNOTATION")
		echo "$DETAIL_NO_ANNOTATION" >> $log_file
	;;	
	"$REASON_INCORECT_HEAD_ANNOTATION")
		echo "$DETAIL_INCORECT_HEAD_ANNOTATION" >> $log_file
	;;	
	"$REASON_UNKNOWN")	
		echo "$DETAIL_UNKNOWN" >> $log_file
	;;
	esac
	
	echo "$diff" >> $log_file
}

function analyze_commit_log(){
	local commit_log=$1
	
	#
	#do some check
	#
	
	return 0
}

DIFF_PASS=0
REASON_UNKNOWN=1
REASON_INCORECT_HEAD_ANNOTATION=2
REASON_NO_ANNOTATION=3
REASON_VENDOR_EDIT_UNMATCHED=4
REASON_ADDED_FILE_WITHOUT_EXP=5

function analyze_diff(){
	local diff="$1"
	local lines=$(echo "$diff" | wc -l)
	local diff_name=$(echo "$diff" | head -n 1)
	
	local ret=$DIFF_PASS
	get_diff_type "$(echo "$diff" | sed -n 1,3p)"
	
	case "$?" in
	"$TYPE_ADD") 
		analyze_add "$diff"
		ret=$?
		;;
	"$TYPE_DELETE") 
		analyze_delete "$diff"
		ret=$?
		;;
	"$TYPE_MODIFICATION") 
		analyze_modification "$diff"
		ret=$?
		;;
	*) echo "Unknown modification type for \"${diff_name}\" "
		return $REASON_UNKNOWN
	   ;;
	esac	

	return $ret
}

REGEX_BINARY_FILE="^Binary files"
#including two meanings:
#1. add a new source or lib file
#2. modify a lib file
function analyze_add(){
	local diff=$1
	
	#add a new file
	local marked_line=$(echo "$diff" | sed -n 4p)
	
	#modify a lib
	local marked_line1=$(echo "$diff" | sed -n 3p)
	
	
	if [ ! -z "$(echo "${marked_line1}." | grep -E "$REGEX_BINARY_FILE")" ] #modify a lib, like *.apk, *.so
	then
		#Binary files a/apps/IRRemoteControler/OppoIREpg.apk and b/apps/IRRemoteControler/OppoIREpg.apk differ
		local file_name=$(echo "$marked_line1" | awk '{print $5}')
		echo "file_name: $file_name"
		local suffix=".$(echo "$file_name" | awk -F "." '{print $2}')"
		local has_exp=$(echo "$file_name" | grep -iE ".*_exp${suffix}")
		if [ -z "$has_exp" ]
		then
			return $REASON_ADDED_FILE_WITHOUT_EXP
		fi
	elif [ ! -z "$(echo "${marked_line}." | grep -E "$REGEX_BINARY_FILE")" ] #add  a new lib, like *.apk, *.so
	then
		#Binary files /dev/null and b/ddr.img differ
		local file_name=$(echo "$marked_line" | awk '{print $5}')
		echo "file_name: $file_name"
		local suffix=".$(echo "$file_name" | awk -F "." '{print $2}')"
		local has_exp=$(echo "$file_name" | grep -iE ".*_exp${suffix}")
		if [ -z "$has_exp" ]
		then
			return $REASON_ADDED_FILE_WITHOUT_EXP
		fi
	else #add a new source file, like *.java, *.c and so on
		local has_vendor_edit=$(echo "$diff" | grep -m 1 -i "VENDOR_EDIT")
		local has_author=$(echo "$diff" | grep -m 1 -i "Author:")
		local has_description=$(echo "$diff" | grep -m 1 -i "Description:")
		local has_revision_history=$(echo "$diff" | grep -m 1 -i "Revision History:")
		
		if [ -z "$has_vendor_edit" -o \
			 -z "$has_author" -o 	  \
			 -z "$has_description" -o \
			 -z "$has_revision_history" ];
		then
			return "$REASON_INCORECT_HEAD_ANNOTATION"
		fi
	fi
	
	return $DIFF_PASS
}

function analyze_delete(){
	#do nothing now
	echo "analyze_delete"
	
	return $DIFF_PASS
}

function analyze_modification(){
	echo "analyze_modification"
	return $DIFF_PASS
}

function get_git_range(){
	#git index in $DB_LIST_FILE
	local idx="$1"
	
	#the line like this: 
	#3:###Database###:/home/stoneami/work/some_code/msm8939_14061/MSM8939_LA_1_0_20_3/android/bionic
	#The "3" is the line in log file; the git name is after "###"
	local begin=$(sed -n ${idx}p $DB_LIST_FILE | awk -F ":" '{print $1}' )
	local end=-1
	if [ $idx -lt $DB_AMOUNT ]
	then
		end=$(sed -n $((idx+1))p $DB_LIST_FILE | awk -F ":" '{print $1}')
	else
		#The last line in log file
		end=$(wc -l ${LOG_FILE} | awk '{print $1}')
	fi	
	
	if((end-begin==1||end-begin==0));
	then
		return 0
	else
		local git=$(get_git_name $idx)
		echo "-------------------------------get_git_range--------------------------------------"
		echo "GIT:${git}"
		echo "Range:(${begin}, $((end-1)))"
		echo "-------------------------------get_git_range--------------------------------------"
		return $((end-begin-1))
	fi
}

TYPE_ADD=1
TYPE_DELETE=2
TYPE_MODIFICATION=3
TYPE_UNKNOWN=0
REGEX_ADD="^new file|^Binary files"
REGEX_DELETE="^deleted file"
REGEX_MODIFICATION="^index "
function get_diff_type(){
	local content="$1"
	local marked_line=$(echo "$content" | sed -n 2p)
	local marked_line1=$(echo "$content" | sed -n 3p)
	
	if [ ! -z "$(echo "$marked_line" | grep -E "$REGEX_ADD" )" -o ! -z "$(echo "$marked_line1" | grep -E "$REGEX_ADD" )" ]
	then
		return $TYPE_ADD
	elif [ ! -z "$(echo "$marked_line" | grep -E "$REGEX_DELETE" )" ]
	then
		return $TYPE_DELETE
	elif [ ! -z "$(echo "$marked_line" | grep -E "$REGEX_MODIFICATION" )" ]
	then
		return $TYPE_MODIFICATION
	else
		return $TYPE_UNKNOWN
	fi
}

function print_reason(){
	save_svn_title

	case $1 in
	"$REASON_NO_ANNOTATION")
		echo "${DETAIL_NO_ANNOTATION}" >> $ANALYZED_RESULT
		print_log "---$DETAIL_NO_ANNOTATION"
		;;
	"$REASON_VENDOR_EDIT_UNMATCHED")
		echo "$DETAIL_VENDOR_EDIT_UNMATCHED" >> $ANALYZED_RESULT
		print_log "---${DETAIL_VENDOR_EDIT_UNMATCHED}"
		;;
	"$REASON_INCORECT_HEAD_ANNOTATION")
		echo "$DETAIL_INCORECT_HEAD_ANNOTATION" >> $ANALYZED_RESULT
		print_log "---${DETAIL_INCORECT_HEAD_ANNOTATION}"
		;;
	"$REASON_ADDED_FILE_WITHOUT_EXP")
		echo "$DETAIL_ADDED_FILE_WITHOUT_EXP" >> $ANALYZED_RESULT
		print_log "---${DETAIL_ADDED_FILE_WITHOUT_EXP}"
		;;
	*) echo "$DETAIL_UNKNOWN" >> $ANALYZED_RESULT
		print_log "---${DETAIL_UNKNOWN}"
		;;
	esac
}

function is_annotation_correct(){
	local vendor_count=$1 
	local exp_count=$2
	local single_exp_count=$3
	local ifdef_matched=$4

	if [ $vendor_count -eq 0 -a $exp_count -eq 0 ];
	then
		return $REASON_NO_ANNOTATION
	fi

	if [ $ifdef_matched -eq 0 ];
	then
		return $REASON_VENDOR_EDIT_UNMATCHED
	fi

	return 0
}

function is_risk_log_correct(){
	local risk_line=$1
	risk_line=${risk_line/$SVN_LOG_RISK_KEYWORD/}
	
	if [ "$(echo "$risk_line" | grep -E "^${SVN_LOG_BAD_RISK_CONTENT}")" ];
	then
		return 1
	else
		return 0
	fi
}

###output begin {
function print_usage(){
	echo "Usage:"
	echo "	./submit_checker \"1900-01-01 06:00:00\" \"1900-01-31 18:30:59\" "
}

function print_result(){
	local ignored_svn_count=0
	local ignored_svn=$(grep "$IGNORE_MARK" $RUNNING_LOG_FILE)
	if [ ! -z "$ignored_svn" ];
	then
		echo "$ignored_svn" > $IGNORED_SVN_FILE
		ignored_svn_count=$(wc -l $IGNORED_SVN_FILE | awk '{print $1}')
	fi
	
	local bad_svn_log_count=0	
	if [ -f $BAD_SVN_LOG_FILE ];
	then
		bad_svn_log_count=$(grep -E '^r[0-9]+' $BAD_SVN_LOG_FILE| wc -l)
	fi
	
	local svn_warning_count=$(find $OUT_DIR -maxdepth 1 -type f | grep "warning*" | wc -l)
	local svn_total=$(wc -l $REDUCED_LOG_FILE | awk '{print $1}')
	
	local analysis_end=$(date +%s)
	local total_seconds=$((analysis_end-ANALYSIS_START+1))
	if [ $total_seconds -lt 60 ];
	then
		ret="${total_seconds} seconds"
	else
		min=$((total_seconds/60))
		sec=$((total_seconds%60))
		ret="${min} minutes, ${sec} seconds"
	fi
	printf "\nAnalysis has been done (takes ${ret})"
	
	if [ "${SVN_CHECK_COUNT}" -eq "-1" ];
	then
		printf "\nTotal SVN(${START_SVN}~${END_SVN}): ${svn_total}"
	else
		printf "\nTotal SVN: ${svn_total}"
	fi
	printf "\nIgnored SVN: ${ignored_svn_count}"
	printf "\nBad SVN LOG: ${bad_svn_log_count}"
	printf "\nWarning SVN: ${svn_warning_count}"
	printf "\nWarning Rate: $((svn_warning_count*100/svn_total))%%\n"
	
	echo "You can find the details in ${OUT_DIR}"
}

function clear_cache(){	
	rm -rf $TEMP_DIR
}

####################################################
RUN_TIME=$(date +%s)

USING_LAST_CFG=$1

IGNORE_MARK="**Ignore:"

#"2014-10-31 06:00:00"
GIT_START_TIME=$1
GIT_END_TIME=$2

DB_MARK="###Database###:"

DATE_RANGE=1
UNKNOWN=0

REGEX_COMMIT_ID="^[a-zA-Z|0-9]+$"
REGEX_DATE="^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"

REGEX_WARNING_INFO_FILTER="^-|^Index:"  #"^-[[:blank:]]+|^-[a-zA-Z]|^Index:"
REGEX_FILTER_KEY_WORDS="svn merge|merge code|add.*code|s[trin]{4}g|词条|同步.*内销|上传.*代码|编译错误|build error|更改.*代码.*位置.*|回退.*提交|auto tool|update merge|merge|delete values"
REGEX_NON_CODE_TYPE="string.*\.xml$|array.*\.xml$|\.apk$|build\.xml$|\.png$|\.jp[e]{0,1}g$|\.jar$|\.so$|\.a$|\.bin$|\.ogg$|^[^.]+$"
REGEX_IMAGE_JAR_SO="\.png$|\.jpg$|\.jpeg$|\.jar$|\.so$|\.a$|\.bin$|\.ogg$"
REGEX_IMAGE_JAR_SO_WITH_EXP="_exp\.png$|_exp\.jpg$|_exp\.jpeg$|_exp\.jar$|_exp\.so$|_exp.a$|_exp\.bin$"
REGEX_SINGLE_BRACE_LINE="^-([[:blank:]]*)\}([[:blank:]]*)"

SVN_LOG_RISK_KEYWORD="风险："
SVN_LOG_BAD_RISK_CONTENT="无。"

#The out dir
CUR_DIR=$PWD
OUT_DIR=$CUR_DIR/OUT

CFG_DIR=$CUR_DIR/config
LAST_CFG_FILE=${CFG_DIR}/last_config.txt

#Temporary files
TEMP_DIR=${OUT_DIR}/temp
DB_LIST_FILE=${TEMP_DIR}/db_list.txt
LOG_FILE=${OUT_DIR}/commit_log.txt

IGNORED_COMMIT_FILE=${OUT_DIR}/ignored.txt
BAD_COMMIT_LOG_FILE=${OUT_DIR}/bad_commit_log.txt
######################Let's begin######################

main
