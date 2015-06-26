#!/bin/bash

function need_check(){	
	ignore=$(grep 'svn merge\|update strings' $1)
	
	if [ -z "$ignore" ];	
	then
		echo 1
	else		
		echo 0	
	fi
}

check=$(need_check log2.txt)
echo check=$check
if [ $check -eq 1 ] ;
then
	echo need check !
else
	echo no check...
fi

#!/bin/bash
function test(){
POS=15
echo -n "Doing ... "
for((i=0;i<=100;i++))
do
echo -en "\\033[${POS}G $i % completed" 
sleep 0.1
done
echo -ne "\n"
}

test