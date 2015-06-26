#!/bin/bash

NEED_OUT=$1

if [ "$NEED_OUT" != "no-out" ];
then
	echo "need out"
else
	echo "no out"
fi


#i=0
#max=100
#while(($i<=$max))
#do
#	echo "i=$i"
#	((i++))
#done

function test(){
	local i=0
	for((i=1;i<10;i++)){
		for((j=1;j<2;j++)){
			echo "$i"
		}
	}
}

test

echo "j=$j"
