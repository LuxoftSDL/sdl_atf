#!/usr/bin/env bash

# apt-get install sysstat linux-tools-common

SDL_PID=$(pidof smartDeviceLinkCore)
REMOTE=false
OUTPUT_DIR="measure"/$1
OUTPUT_PIDSTAT_FILE=$OUTPUT_DIR/pidstat.log
OUTPUT_PS_FILE=$OUTPUT_DIR/ps.log
OUTPUT_DOCKER_FILE=$OUTPUT_DIR/docker.log

STEP=1

if [ -n $2 ] && [ "$2" = "--remote" ]; then REMOTE=true; fi

rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR
pwd
echo $OUTPUT_DIR
function ps_formated() {
    ps  --no-headers --format "start %cpu cp cputime %mem sz thcount " -p $SDL_PID
}

function measure_ps() {
    PS_OUTPUT=$(ps_formated)
    TIME=$(date +'%T:%N')
    echo $TIME $PS_OUTPUT >> $OUTPUT_PS_FILE
}

function measure_pid_stat() {
    export S_TIME_FORMAT=ISO
    STAT_OUTPUT=$(pidstat -urdlv -h -p $SDL_PID | grep $SDL_PID)
    echo $STAT_OUTPUT >> $OUTPUT_PIDSTAT_FILE
}

function measure_docker() {
    RECORD=$(docker stats --format "{{.Name}} {{.CPUPerc}} {{.MemUsage}}  {{.PIDs}}"  --no-stream | grep remote_sdl)
    echo $RECORD
    TIME=$(date +'%T:%N')
    echo $TIME $RECORD >> $OUTPUT_DOCKER_FILE
}

echo "Wait for SDL start"
until SDL_PID=$(pidof smartDeviceLinkCore)
do
    sleep $STEP
    printf "."
done

while SDL_PID=$(pidof smartDeviceLinkCore)
do
    measure_pid_stat
    measure_ps
    if [ $REMOTE = true ]; then measure_docker; fi
    sleep $STEP
done

PARAMS="--pidstat_file=$OUTPUT_PIDSTAT_FILE --ps_file=$OUTPUT_PS_FILE --output_dir=$OUTPUT_DIR --title=$1"
if [ $REMOTE = true ]; then PARAMS="$PARAMS --docker_file=$OUTPUT_DOCKER_FILE"; fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" 
python3 $DIR/sdl_graphs.py $PARAMS
