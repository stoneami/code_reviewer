#!/bin/bash

CODE_PATH="http://192.168.1.241/svn/msm8974/msm8974_2030205_dev_rom/"
LOG_FILE="svn_log.txt"
LOG_FILE_EXP="svn_log_exp.txt"

EXPORT_SVN_USERNAME_REGEX="wuqingsong|maozongjian|huyong|liuzhiyong|mayugang|bailipeng|lile|wanghanqing|huqiao|tianxiaohua|liaofuchun|zhanglong|zhangjiamin|wuyisheng|tuminglu|yimin|zhaoyongjie|shitongjing|shaoming|chenting|hongyu.bi|zhangzhipan|weidedong|huangdidan|duhuan|wangzhi|zhangwensheng|wangjm|liuli|wangzequan|yangguofu|jiejunren|jianbo.chen|chenqianyi|chengjun|tangjunhao|liuyuanfei|lihu|mashaolong|chenxiaoyan|gengxiaoyan|tanjifeng|shujin|liulisen|yanwenchen|luoqiaoyi|zhangweichao|hui.yang|liulei|caojun|ouzhengdong|qiang.shao|chenlei|oppoexp"

DELETE_REGEX="^分析|^方案|^风险|^提交类型|^Test Plan|^Reviewed By|^Differential Revision|^$|^检视人"

function fn_remove_domestic_svn(){
	echo -n "begin: "
	date

	local revision_count=$(grep -En "^r" $LOG_FILE_EXP | wc -l)
	
	local index=1
	local depth=1
	while [ "$index" -le "$revision_count" ]
	do
		local svn_username=$(grep -m "${depth}" -En "^r" $LOG_FILE_EXP | tail -n -1 | awk -F "|" '{print $2}')
		local is_export_username=$(echo "${svn_username}" | grep -E "${EXPORT_SVN_USERNAME_REGEX}")

		#Domestic username
		if [ -z "${is_export_username}" ];
		then
			local target_revesion_content_line=$(grep -m "${depth}" -En "^r" $LOG_FILE_EXP | tail -n -1 | awk -F ":" '{print $1}')
			local next_revision_content_line=
			if [ "$index" -lt "$revision_count" ];
			then
				next_revision_content_line=$(grep -m "$((depth+1))" -En "^r" $LOG_FILE_EXP | tail -n -1 | awk -F ":" '{print $1}')
				((next_revision_content_line--))
			else
				next_revision_content_line=$(wc -l $LOG_FILE_EXP | awk '{print $1}')
			fi
			
			sed -ri "${target_revesion_content_line},${next_revision_content_line}d" $LOG_FILE_EXP
			((depth--))
		fi
				
		((depth++))
		((index++))
	done

	sed -ri "/${DELETE_REGEX}/d" $LOG_FILE_EXP

	echo -n "end: "
	date
}

svn log --username "liulei" --password "liulei" $CODE_PATH > $LOG_FILE

cp "$LOG_FILE" "$LOG_FILE_EXP"

fn_remove_domestic_svn
