#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

# exp: perf
# variance: (parsec3|splash2x|ycsb|mysqld)/<workload>/(orig|thp|ethp|rec|prec)
#     For ycsb, <workload> is the zipfian alpha value.
#     For mysqld, <workload> is (read|write|oltp)-<runtime in seconds>
# $1: <...>/results/<exp>/<variance>/0(0-9)

if [ $# -ne 1 ]
then
	echo "Usage: $0 <output dir>"
	exit 1
fi

BINDIR=$(dirname "$0")
ODIR=$1

DAMO_WRAPPER="$BINDIR/_run_damo.sh"
repos_dir="$(dirname "$0")/../../../../"
PARSEC_RUN="$repos_dir/parsec3_on_ubuntu/run.sh"
SILO_DBTEST="$repos_dir/silo/out-perf.masstree/benchmarks/dbtest"
DAMO="$repos_dir/damo/damo"
LBX="$repos_dir/lazybox"
scheme=""
timeout=3600

EXP_DIR="$ODIR/../../../../../../perf/"
var=$(basename $(dirname $ODIR))
work=$(basename $(dirname $(dirname $ODIR)))
work_category=$(basename $(dirname $(dirname $(dirname $ODIR))))
echo $work_category $work

if [ "$work_category" = "splash2x" ]
then
	RUN_CMD="$PARSEC_RUN splash2x.$work"
elif [ "$work_category" = "parsec3" ]
then
	RUN_CMD="$PARSEC_RUN $work"
elif [ "$work_category" = "ycsb" ]
then
	RUN_CMD="$SILO_DBTEST --bench ycsb --verbose --scale-factor 1000 \
		--runtime 60 -o --zipfian-alpha=$work"
elif [ "$work_category" = "mysql" ]
then
	timeout=$(echo $work | awk -F'-' '{print $2}')
	RUN_CMD="sleep \"$timeout\""
else
	echo "Unsupported work category $work_category"
	exit 1
fi

RUN_CMD+=" | tee $ODIR/commlog"

echo "RUN_CMD: $RUN_CMD"

# ttmo for too-simplified TMO (to be compared with plrus)
if [ "$var" = "orig" ] || [ "$var" = "thp" ] || [ "$var" = "ttmo" ]
then
	if [ "$var" = "thp" ]
	then
		sudo $LBX/scripts/turn_thp.sh always
	else
		sudo $LBX/scripts/turn_thp.sh madvise
	fi

	eval $RUN_CMD
	exit
fi

# var is neither 'orig' nor 'thp'
sudo $LBX/scripts/turn_thp.sh madvise
eval $RUN_CMD &

cmdname=$work
if [ "$work_category/$work" = "parsec3/raytrace" ]
then
	cmdname="rtview"
elif [ "$work_category" = "ycsb" ]
then
	cmdname="dbtest"
elif [ "$work_category" = "mysql" ]
then
	cmdname="mysqld"
fi

for i in {1..10}
do
	pid=`pidof $cmdname`
	if [ $? -eq 0 ]
	then
		break
	elif [ $? -ne 0 ] && [ $i -eq 10 ]
	then
		echo "No pid found"
		exit 1
	fi
	echo 'wait for pidof '$cmdname
	sleep 1
done

schemes_dir="$EXP_DIR/schemes"
custom_schemes_dir="$schemes_dir/$work_category/$work"

if [ "$var" = "rec" ]
then
	sudo "$DAMO_WRAPPER" \
		"$DAMO" "record" "$ODIR/damon.data" "" "$pid" "$pid" "$timeout"
elif [ "$var" == "ethp" ] || [[ "$var" == "prcl"* ]] || [[ "$var" == "darc"* ]]
then
	if [ -f "$custom_schemes_dir/$var.damos" ]
	then
		scheme="$custom_schemes_dir/$var.damos"
	else
		scheme="$schemes_dir/$var.damos"
	fi
	echo "apply scheme '$scheme'"
	sudo "$DAMO_WRAPPER" \
		"$DAMO" "schemes" "" "$scheme" "$pid" "$pid" "$timeout"
elif [ "$var" = "prec" ]
then
	sudo "$DAMO_WRAPPER" \
		"$DAMO" "record" "$ODIR/damon.data" "" paddr "$pid" "$timeout"
elif [ "$var" = "pprcl" ] || [[ "$var" == "pdarc"* ]] || \
	[[ "$var" == "plrus-"* ]]
then
	scheme_name="$var"
	if [[ "$scheme_name" == "plrus-"* ]]
	then
		# -nomp suffix for no memory pressure
		scheme_name=$(echo "$scheme_name" | awk -F"-nomp" '{print $1}')
	fi

	if [ -f "$custom_schemes_dir/$scheme_name.damos" ]
	then
		scheme="$custom_schemes_dir/$scheme_name.damos"
	else
		scheme="$schemes_dir/$scheme_name.damos"
	fi
	echo "apply scheme '$scheme'"
	sudo "$DAMO_WRAPPER" \
		"$DAMO" "schemes" "" "$scheme" paddr "$pid" "$timeout"
else
	echo "Wrong var $var"
	killall $cmdname
	exit 1
fi
