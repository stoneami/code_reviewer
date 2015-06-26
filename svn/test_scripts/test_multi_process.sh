#!/bin/bash

MAX=10
CON=4

function main(){
	for((i=0;i<$MAX;))
	do
		for((j=0;j<$CON && i<$MAX;j++))
		do
			multi_print $j &
			i=$((i+1))
		done

		wait
	done
}

function multi_print(){
	echo "multi_print: $1"
}

main
