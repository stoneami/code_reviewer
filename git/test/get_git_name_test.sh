#!/bin/bash
function get_git_name(){
	#git index in $DB_LIST_FILE
	local idx="$1"
	local local_path=$(sed -n ${idx}p "db_list.txt" | awk -F ":" '{print $3}' )
	local git_name=${local_path#$CUR_DIR/}
	echo "$git_name"
}

git_index=1
git_name=$(get_git_name "$git_index" | sed -r 's:/:-:g')

echo "git: ${git_name}"

