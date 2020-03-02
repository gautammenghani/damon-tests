#!/bin/bash

ODIR=$1
work=$(basename $(dirname $(dirname $ODIR)))
if [ "$work" = "raytrace" ]
then
	work="rtview"
fi

while true;
do
	pid=`pidof $work`
	if [ $pid ]
	then
		ps -o vsz=,rss=,pid=,cmd= --pid `pidof $work` >> $1/memfps
	fi
	sleep 1
done