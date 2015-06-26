#!/bin/bash

# -------------------------------------------------------------------------------
# Filename:    submit_checker.sh
# Revision:    1.0
# Date:        2014/04/10
# Author:      Jerry
# Email:       liulei@oppo.com
# Description: Check the SVN submitting     
# -------------------------------------------------------------------------------

function main(){
	
	init_option
	
	if [ $? -eq 0 ];
	then
		echo "Usage: ./submit_checker <URL|PATH> <r1:r2> [is_project_svn]"
		printf  "\nEmail: liulei@oppo.com\nVersion: 1.0\n"
		return 0
	fi
	
	#create essential Log files
	obtain_svn_log

	#analyze the Code modification
	analyze_svn_submitting
}

function init_option(){	
	if [ ! $CODE_PATH -o ! $OPTION ];
	then
		return 0
	else
		if [ $(echo $OPTION | grep -E '^([0-9]+):([0-9]+)$') ];
		then
			START_SVN=$(echo $OPTION | awk -F : '{print $1}')
			END_SVN=$(echo $OPTION | awk -F : '{print $2}')
		elif [ $(echo $OPTION | grep -E '^([0-9]+)$') ];
		then
			SVN_CHECK_COUNT=$OPTION
		else
			return 0
		fi
	fi
	
	return 1
}

function remove_domestic_svn(){
	local revision_count=$(grep -En "^r" $LOG_FILE | wc -l)
	
	local index=1
	local depth=1
	while [ "$index" -le "$revision_count" ]
	do
		local svn_username=$(grep -m "${depth}" -En "^r" $LOG_FILE | tail -n -1 | awk -F "|" '{print $2}')
		local is_export_username=$(echo "${svn_username}" | grep -E "${EXPORT_SVN_USERNAME_REGULAR}")

		#Domestic username
		if [ -z "${is_export_username}" ];
		then
			local target_revesion_content_line=$(grep -m "${depth}" -En "^r" $LOG_FILE | tail -n -1 | awk -F ":" '{print $1}')
			local next_revision_content_line=
			if [ "$index" -lt "$revision_count" ];
			then
				next_revision_content_line=$(grep -m "$((depth+1))" -En "^r" $LOG_FILE | tail -n -1 | awk -F ":" '{print $1}')
				((next_revision_content_line--))
			else
				next_revision_content_line=$(wc -l $LOG_FILE | awk '{print $1}')
			fi
			
			sed -ri "${target_revesion_content_line},${next_revision_content_line}d" ${LOG_FILE}
			((depth--))
		fi
				
		((depth++))
		((index++))
	done
}

function obtain_svn_log(){
	rm -rf $OUT_DIR
	mkdir -m 777 -p "${TEMP_DIR}"
	
	print_log "START_SVN=${START_SVN}, END_SVN=${END_SVN}, SVN_CHECK_COUNT=${SVN_CHECK_COUNT}"

	local create_begin=$(date +%s)
	
	#Specify the SVN
	if [ "$START_SVN" -a "$END_SVN" ];
	then
		if [ "${START_SVN}" -gt "${END_SVN}" ];
		then
			local temp_svn=$START_SVN
			START_SVN=$END_SVN
			END_SVN=$temp_svn			
		fi
		
		#Obtain the svn logs
		svn log -r "${END_SVN}:${START_SVN}" $CODE_PATH > $LOG_FILE
		
		#Remove unnecesary line
		sed -ri '/^$|^------/d' $LOG_FILE
		
		#Remove domestic svn submitting
		if [ "$PROJECT_SVN" == "1" ];
		then
			remove_domestic_svn
		fi
		
		#Create reduced log file for analysis
		grep -E '\<r[0-9]+' $LOG_FILE > $REDUCED_LOG_FILE
	
	#Specify the checking count
	else
		#Create all SVN logs
		svn log $CODE_PATH > $LOG_FILE
		
		#remove unnecesary line
		sed -ri '/^$|^------/d' $LOG_FILE
		
		#Remove domestic svn submitting
		if [ "$PROJECT_SVN" == "1" ];
		then
			remove_domestic_svn
		fi
			
		#Create reduced log file for analysis			
		grep -E '\<r[0-9]+' -m $((SVN_CHECK_COUNT+1)) $LOG_FILE > $REDUCED_LOG_FILE
	
		#Remove redundant logs
		local last_line=$(wc -l $REDUCED_LOG_FILE | awk '{print $1}')
		if [ $last_line -ge $((SVN_CHECK_COUNT+1)) ];
		then
			print_log "Need to remove redundant logs"
			
			local last_line_content=$(sed -n ${last_line}p $REDUCED_LOG_FILE)	
			local match_line=$(grep -rn "$last_line_content" -m 1 $LOG_FILE | awk -F : '{print $1}')
			local last_line_in_log_file=$(wc -l $LOG_FILE | awk '{print $1}')

			#remove unnecessary log
			sed -ri "${match_line},${last_line_in_log_file}d" $LOG_FILE
			sed -ri '$d' $REDUCED_LOG_FILE
		fi
	fi	
	
	local create_end=$(date +%s)	
	printf "\nSVN Logs have been created (takes %ds)\n" $((create_end-create_begin))
}

function is_svn_need_check(){
	local new_svn=$1	
	local old_svn=$2
	
	local start_line=$(grep -m 1 -En "^r${new_svn} \|" $LOG_FILE | awk -F : '{print $1}')
	local end_line=
	if [ $old_svn -ne "-1" ];
	then
		end_line=$(grep -m 1 -En "^r${old_svn} \|" $LOG_FILE | awk -F : '{print $1}')
		end_line=$((end_line-1))
	else
		end_line=$(wc -l $LOG_FILE | awk '{print $1}')
	fi

	local ignore="need check"
	if [ $end_line -gt $start_line ];
	then
		ignore=$(sed -n $((start_line+1))p $LOG_FILE  | grep -E "$FILTER_KEY_WORDS")
	else
		echo "$(grep -m 1 -En "^r${new_svn} \|" $LOG_FILE) has no log ???"
		ignore="need check"
	fi
	
	if [ -z "$ignore" ];
	then
		return 1
	else
		print_log "**Ignore: SVN${new_svn}--${ignore}\n"		
		return 0
	fi
}

function is_annotation_correct(){
	local vendor_count=$1 
	local exp_count=$2
	local single_exp_count=$3
	local ifdef_matched=$4

	if [ $ifdef_matched -eq 0 ];
	then
		return $REASON_VENDOR_EDIT_UNMATCHED
	fi
	
	local x=$((vendor_count-2*(exp_count-single_exp_count)))
	local y=$((3*(exp_count-single_exp_count)-vendor_count))

	if [ $x -lt 0 -o $y -lt 0 ];
	then
		return $REASON_NO_ANNOTATION
	fi
	
	if [ $x -eq 0 -a $y -eq 0 -a $single_exp_count -eq 0 ];
	then
		return $REASON_NO_ANNOTATION
	fi

	return 0
}

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
	local diff_content="$(sed -n ${DIFF_START},${DIFF_END}p $DIFF_FILE)"
	local max_line=$(echo "$diff_content" | wc -l)
	
	if [ "$(echo "$diff_content" | sed -n 4,${max_line}p | grep -E '^\+')" ];
	then
		return 0
	fi
	
	local path=$(echo "$diff_content" | head -n 1)
	
	get_source_file_type "${path}"
	
	case "$?" in
	"$JAVA_TYPE") 
		if [ "$(echo "$diff_content" | grep -m 1 -E 'package .*;')" ];
		then
			return "$JAVA_TYPE"
		fi
		;;
	"$C_TYPE") 
		if [ "$(echo "$diff_content" | grep -m 1 -E 'namespace .*{')" ];
		then
			return "$C_TYPE"
		fi
		;;
	"$XML_TYPE") 
		if [ "$(echo "$diff_content" | grep -m 1 -E 'xml version=.1.0. encoding=.UTF-8')" ];
		then
			return "$XML_TYPE"
		fi
		;;
	*) return "$OTHER_TYPE"
	   ;;
	esac
}

function print_reason(){
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
	*) echo "Unkonwn reasons" >> $ANALYZED_RESULT
		print_log "---Unkonwn reasons"
		;;
	esac
}

function analyze_added_source_file(){
	print_log "***It is an new source file"
	local diff_content=$(sed -n ${DIFF_START},${DIFF_END}p $DIFF_FILE)
	local has_vendor_edit=$(echo "$diff_content" | grep -m 1 -i "VENDOR_EDIT")
	local has_author=$(echo "$diff_content" | grep -m 1 -i "Author:")
	local has_description=$(echo "$diff_content" | grep -m 1 -i "Description:")
	local has_revision_history=$(echo "$diff_content" | grep -m 1 -i "Revision History:")
	
	if [ -z "$has_vendor_edit" -o \
		 -z "$has_author" -o 	  \
		 -z "$has_description" -o \
		 -z "$has_revision_history" ];
	then
		print_reason "$REASON_INCORECT_HEAD_ANNOTATION"
		print_log "---Warning: ${INDEX_FILE##*/}: DIFF_START=${DIFF_START}, DIFF_END=${DIFF_END}\n"		
		sed -n ${DIFF_START},${DIFF_END}p $DIFF_FILE  | grep -E "$WARNING_INFO_FILTER_REGULAR" >> $ANALYZED_RESULT
		printf "\n" >> $ANALYZED_RESULT
	else
		print_log "***${INDEX_FILE##*/} is added source file and has correct annotation\n"
	fi
}

function analyze_modified_source_file(){
	print_log "***It is a modified source file "
	local count_vendor_edit=0
	local count_exp=0
	
	IFDEF_REGULAR="if[n]*def.*VENDOR_EDIT"
	ENDIF_REGULAR="endif.*VENDOR_EDIT"

	local diff_content=$(sed -n $((DIFF_START+3)),${DIFF_END}p $DIFF_FILE |  grep -E '^-')
	local line_num=$(echo "${diff_content}" | wc -l | awk '{print $1}')
	
	local count_of_ifdef=0

	EXP_LINE_REGULAR=".*@EXP\..*\..*"
	
	local count_single_exp=0
	local ifdef_in_pair=1
	local checked_line=1
	local during_single_exp=0
	while [ $checked_line -le $line_num ]
	do
		#Read one line
		local modified_line_content=$(echo "${diff_content}" | sed -n ${checked_line}p )
		checked_line=$((checked_line+1))

		#Only check the line head of '-'
		if [ ! "$(echo "${modified_line_content}" | grep -iE '^-')" ];
		then
			continue
		fi

		#Check the VENDOR_EDIT pairs
		#The correct annotation is like
		#//abc.xyz@Exp.Group...
		#...
		#//#ifndef VENDOR_EDIT
		#...
		#//#endif /* VENDOR_EDIT */
		#//abc.xyz@Exp.Group...
		#...
		#//#ifndef VENDOR_EDIT
		#...
		#//#endif /* VENDOR_EDIT */
		#//abc.xyz@Exp.Group...
		#...		
		
		#Begin a new match
		if [ $count_of_ifdef -eq 0 ];
		then
			#New vendor_edit begin
			if [ "$(echo "$modified_line_content" | grep -E "${IFDEF_REGULAR}")" ];
			then
				count_of_ifdef=$((count_of_ifdef+1))
				during_single_exp=0
			elif [ "$(echo "$modified_line_content" | grep -E "${EXP_LINE_REGULAR}")" ];
			then
				during_single_exp=1
				((count_single_exp++))
			elif [ "$during_single_exp" -eq "1" ];
			then
				echo "do nothing" > /dev/null
			else
				ifdef_in_pair=0
			fi
		else
			if [ "$(echo "$modified_line_content" | grep -E "${IFDEF_REGULAR}")" ];
			then
				count_of_ifdef=$((count_of_ifdef+1))
			elif [ "$(echo "$modified_line_content" | grep -E "${ENDIF_REGULAR}")" ]
			then
				count_of_ifdef=$((count_of_ifdef-1))
			fi
		fi

		#Find VENDOR_EDIT ignore case
		if [ "$(echo "${modified_line_content}" | grep -m 1 -iE 'VENDOR_EDIT')" ];
		then
			count_vendor_edit=$((count_vendor_edit+1))
		fi
		
		#Find @Exp ignore case
		if [ "$(echo "${modified_line_content}" | grep -m 1 -iE '@Exp')" ];
		then
			count_exp=$((count_exp+1))
		fi				
	done

	is_annotation_correct "$count_vendor_edit" "$count_exp" "${count_single_exp}" "$ifdef_in_pair"
	local reason=$?

	if [ "$reason" -gt 0 ];
	then
		print_reason "$reason"
		print_log "---Warning: ${INDEX_FILE##*/}: DIFF_START=${DIFF_START}, DIFF_END=${DIFF_END}, vendor_edit=${count_vendor_edit}, exp=${count_exp}, count_single_exp=${count_single_exp}, ifdef_in_pair=${ifdef_in_pair}\n"
		sed -n ${DIFF_START},${DIFF_END}p $DIFF_FILE | grep -E "$WARNING_INFO_FILTER_REGULAR" >> $ANALYZED_RESULT
		printf "\n" >> $ANALYZED_RESULT
	else
		print_log "***${INDEX_FILE##*/}: DIFF_START=${DIFF_START}, DIFF_END=${DIFF_END}, vendor_edit=${count_vendor_edit}, exp=${count_exp}, ifdef_in_pair=${ifdef_in_pair}\n"
	fi
}

function analyze_code_modification(){
	#There is no modification content, maybe it's binary file type, just record it
	if [ $((DIFF_END-DIFF_START)) -lt 2 ];
	then
		print_reason "0" #unknown reason
		print_log "---Warning: ${INDEX_FILE##*/} has no modified content, Why ?\n"
		echo "${INDEX_FILE}" >> $ANALYZED_RESULT
		printf "\n" >> $ANALYZED_RESULT
		return 0
	fi

	is_added_source_file
	
	if [ $? -eq 0 ];
	then
		analyze_modified_source_file
	else
		analyze_added_source_file
	fi
}

#Check if the added file with '_exp'
function analyze_non_code_modification(){
	local is_image_jar_so=$(echo "$INDEX_FILE" | grep -iE "${IMAGE_JAR_SO_REGULAR}")
	if [ $((DIFF_END-DIFF_START)) -eq 0 -a "$is_image_jar_so" ];
	then
		local is_added_or_modified=
		#judge if it is a added file
		if [ $MODIFY_INDEX -lt $MODIFY_COUNT ];
		then
			local next_index_file=$(sed -n $((DIFF_START+1))p $DIFF_FILE)
			if [ "$next_index_file" != "$INDEX_FILE" ];
			then
				is_added_or_modified=1
			else
				print_log "***${INDEX_FILE##*/} has double lines, so we ignore the next Index"
				MODIFY_INDEX=$((MODIFY_INDEX+1))
			fi
		else
			is_added_or_modified=1
		fi
				
		if [ $is_added_or_modified ];
		then
			local add_file_has_exp=$(echo "$INDEX_FILE" | grep -iE "${IMAGE_JAR_SO_WITH_EXP_REGULAR}")
			if [ ! "$add_file_has_exp" ];
			then
				print_reason "$REASON_ADDED_FILE_WITHOUT_EXP"
				echo "$INDEX_FILE" >> $ANALYZED_RESULT
				printf "\n" >> $ANALYZED_RESULT
				print_log "+++Warning: ${INDEX_FILE##*/} is non-code modifictation(added or modified) and has no '_exp'"
			else
				print_log "***${INDEX_FILE##*/} is non-code modifictation(added or modified) and has correct '_exp'"
			fi
		else
			print_log "***${INDEX_FILE##*/} is non-code modifictation(not added), ignore it"
		fi
	else
		print_log "***${INDEX_FILE##*/} is not image or lib, ignore it" 
	fi
}

function analyze_svn_diff(){
	DIFF_FILE=$1
	local submitter=$2
	
	local analyzed_svn=$(echo $DIFF_FILE | awk -F _ '{print $3}')
	ANALYZED_RESULT="${OUT_DIR}/warning_svn_${analyzed_svn}_${submitter}.txt"	
	
	#get the count of modified files
	grep -nE '^Index:' $DIFF_FILE | awk -F : '{print $1}' > $TEMP_INDEX
	
	MODIFY_COUNT=$(wc -l $TEMP_INDEX | awk '{print $1}')
	
	local MODIFY_INDEX=1
	while [ $MODIFY_INDEX -le $MODIFY_COUNT ]
	do
		DIFF_START=$(sed -n ${MODIFY_INDEX}p $TEMP_INDEX | awk '{print $1}' )
		INDEX_FILE=$(sed -n ${DIFF_START}p $DIFF_FILE)
		is_not_code=$(echo "$INDEX_FILE" | grep -iE "${NON_CODE_TYPE_REGULAR}")
		
		if [ $MODIFY_INDEX -lt $MODIFY_COUNT ] ;
		then			
			DIFF_END=$(sed -n $((MODIFY_INDEX+1))p $TEMP_INDEX | awk '{print $1}' )
			DIFF_END=$((DIFF_END-1))
		#for the last line
		else
			DIFF_END=$(wc -l $DIFF_FILE | awk '{print $1}')
		fi
		
		print_log "**analyzing ${INDEX_FILE##*/}: "
		
		if [ "$is_not_code" ];
		then
			analyze_non_code_modification						
		else
			analyze_code_modification
		fi
		
		print_percent "$((60+40*MODIFY_INDEX/MODIFY_COUNT))%"

		MODIFY_INDEX=$((MODIFY_INDEX+1))		
	done
	
	printf "\n"
}

function analyze_svn_submitting(){
	ANALYSIS_START=$(date +%s)
	
	#Calculate the total svn to be checked
	local max_loop=$(wc -l $REDUCED_LOG_FILE | awk '{print $1}')
	
	i=1
	while [ $i -le $max_loop ]
	do
		checked_svn=$(sed -n ${i}p $REDUCED_LOG_FILE | awk '{print $1}' | awk -F 'r' '{print $2}')
		submitter=$(sed -n ${i}p $REDUCED_LOG_FILE | awk -F "|" '{print $2}' | awk '{print $1}')
		
		if [ $i -ne $max_loop ];
		then
			last_svn=$(sed -n $((i+1))p $REDUCED_LOG_FILE | awk '{print $1}' | awk -F 'r' '{print $2}')
		else
			last_svn=-1
		fi		
		
		pre_svn=$((checked_svn-1))
		
		temp_diff="${TEMP_DIR}/svn_diff_${checked_svn}_${pre_svn}.txt"
		
		i=$((i+1))
		
		#Filter the special SVN (string modification or code porting)
		is_svn_need_check $checked_svn $last_svn 

		if [ $? -eq "1" ] ;
		then
			if [ "$DEBUG" == "1" ]
			then
				printf "\nAnalyzing SVN $checked_svn ...\n"
			else
				echo -n "Analyzing SVN $checked_svn ..."
			fi
			
			print_percent "0%"

			#Step 1: create the svn diff file
			svn diff -x -b -r $checked_svn:$pre_svn $CODE_PATH > $temp_diff
			
			print_log "**${temp_diff##*/} is created."

			print_percent "60%"
			
			#Step 2: remove ^M and unnecessary lines
			sed -ri -e 's///g' -e '/^[-\+]([[:blank:]]+)$|^[-\+]$/d' -e '/(^[-\+]|^Index:)(.*)/!d' $temp_diff
			
			#Step 3: Analyze the svn diff file
			analyze_svn_diff $temp_diff $submitter
			
			sleep $INTERVAL
		else
			echo "SVN $checked_svn is ignored !"
			continue
		fi		
	done
		
	print_result
	
	clear_cache
}

function clear_cache(){
	if [ "$DEBUG" == "1" ]
	then
		return 0
	fi
	
	rm -rf $TEMP_DIR
}

function print_log(){
	if [ "$DEBUG" != "1" ]
	then
		return 0
	fi
	
	for l in "$@"
	do
		printf "\n$l"
	done
}

function print_percent() {
	if [ "$DEBUG" == "1" ]
	then
		return 0
	fi
	
	echo -en "\\033[25G $1 completed"
}

function print_result(){
	local svn_warning_count=$(find $OUT_DIR -maxdepth 1 -type f | wc -l)
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
	printf "\nWarning SVN: ${svn_warning_count}"
	printf "\nWarning Rate: $((svn_warning_count*100/svn_total))%%\n"
	
	echo "You can find the details in ${OUT_DIR}"
}

###################Main##########################
CODE_PATH=$1

#Maybe a SVN range or a max check count
OPTION=$2
PROJECT_SVN=$3
DEBUG=$4

INTERVAL=0.5

#The SVN range to be checked
START_SVN=
END_SVN=

#How many revisions need to be checked
SVN_CHECK_COUNT=-1

EXPORT_SVN_USERNAME_REGULAR="dedong\.wei|didan\.huang|fuchun\.liao|guangyong\.li|guofu\.yang|hanqing\.wang|hongyu\.bi|\
hu\.li|huan\.du|hui\.yang|jiamin\.zhang|jianbo\.chen|jifeng\.tan|jimin\.wang|jin\.shu|jun\.cao|\
jun\.cheng|junhao\.tang|junren\.jie|le\.li|lei\.chen|lei\.liu|li\.liu|lipeng\.bai|lisen\.liu|\
long\.zhangzhang-wx|min\.yi|ming\.shao|minglu\.tu|qiang\.shao|qiao\.hu|qiaoyi\.luo|qingsong\.wu|\
shaolong\.ma|shengtao\.li|ting\.Chen|tongjing\.shi|wei\.yan|weichao\.zhang|wenchen\.yan|wenquan\.you|\
wensheng\.zhang|xiaohua\.tian|xiaoyan\.chen|xiaoyan\.geng|yisheng\.wu|yong\.hu|yongjie\.zhao|\
yuanfei\.liu|yugang\.ma|zequan\.wang|zhengdong\.ou|zhi\.wang|zhichao\.liu|zhiyong\.liu|zongjian\.mao"

JAVA_TYPE=1 C_TYPE=2
XML_TYPE=3 OTHER_TYPE=0

WARNING_INFO_FILTER_REGULAR="^-|^Index:"  #"^-[[:blank:]]+|^-[a-zA-Z]|^Index:"
FILTER_KEY_WORDS="svn merge|merge code|add.*code|词条|同步.*内销|上传|update.*s[tring]{5}s|编译错误|build error"
NON_CODE_TYPE_REGULAR="string.*\.xml$|array.*\.xml$|\.apk$|build\.xml$|\.png$|\.jp[e]{0,1}g$|\.jar$|\.so$|\.a$|\.bin$"
IMAGE_JAR_SO_REGULAR="\.png$|\.jpg$|\.jpeg$|\.jar$|\.so$|\.a$|\.bin$"
IMAGE_JAR_SO_WITH_EXP_REGULAR="_exp\.png$|_exp\.jpg$|_exp\.jpeg$|_exp\.jar$|_exp\.so$|_exp.a$|_exp\.bin$"

DETAIL_INCORECT_HEAD_ANNOTATION="REASON: There is no or incorrect head annotation"
DETAIL_NO_ANNOTATION="REASON: There is no annotation for code modification"
DETAIL_VENDOR_EDIT_UNMATCHED="REASON: The vendor_edit is not in pair"
DETAIL_ADDED_FILE_WITHOUT_EXP="REASON: There is no '_exp' for the added(or modified) non-code file"
REASON_INCORECT_HEAD_ANNOTATION=1
REASON_NO_ANNOTATION=2
REASON_VENDOR_EDIT_UNMATCHED=3
REASON_ADDED_FILE_WITHOUT_EXP=4

#The out dir
OUT_DIR=./out

#Temporary files
TEMP_DIR=${OUT_DIR}/temp
TEMP_INDEX=${TEMP_DIR}/temp_index.txt
LOG_FILE=${TEMP_DIR}/svn_log.txt
REDUCED_LOG_FILE=${TEMP_DIR}/reduced_svn_log.txt

######################Let's begin######################

main

