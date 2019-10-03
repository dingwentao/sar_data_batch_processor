#!/bin/bash

if [ $# -lt 5 ]; then
    echo "argv list is empty, using default dir"
    root="/media/radarops/"
    refFolder0="d0"
    refFolder1="d8"
    numCh0=8
    numCh1=8    
else
    root=$1
    refFolder0=$2
    refFolder1=$3
    numCh0=$4
    numCh1=$5 
fi

echo "root dir: ${root}"
echo "listing *.mat files"

# NOW=$(date +"%y%m%d_%Hh%Mm%Ss")
# PART_ID_FILE0=uniqueIds__${NOW}.txt
# LINE_NO_FILE=perUniIdLineNo__${NOW}.txt

PART_ID_FILE0=partUniqueIds0.txt
PART_ID_FILE1=partUniqueIds1.txt
All_ID_FILE=allUniqueIds.txt
LINE_NO_FILE=numFilesPerId.txt

touch ${PART_ID_FILE0}
find ${root}${refFolder0} -name "*.mat" | awk 'BEGIN{FS=OFS="_"}{NF--; print}' | awk '!seen[$0]++' > ${PART_ID_FILE0}

touch ${PART_ID_FILE1}
find ${root}${refFolder1} -name "*.mat" | awk 'BEGIN{FS=OFS="_"}{NF--; print}' | awk '!seen[$0]++' > ${PART_ID_FILE1}

if [ -e $All_ID_FILE ]; then
    rm -f $All_ID_FILE
    touch ${All_ID_FILE}
else 
    touch ${All_ID_FILE}
fi

dir1=/media/radarops/
dir2=./d0/
channelName=Channel
lenRefFolder0=${#refFolder0}
lenRefFolder1=${#refFolder1} 
tLenRefFolder0=$(($lenRefFolder0-1))
tLenRefFolder1=$(($lenRefFolder1-1)) 
startCh0=${refFolder0:1:$tLenRefFolder0}
startCh1=${refFolder1:1:$tLenRefFolder1}  
numCh0=$(($startCh0+$numCh0-1))
numCh1=$(($startCh1+$numCh1-1)) 

for i in $(seq ${startCh0} ${numCh0})
do
    echo $i
done

for i in $(seq ${startCh1} ${numCh1})
do
    echo $i  
done

while IFS='' read -r line || [[ -n "$line" ]]; do

    echo "${line}" >> ${All_ID_FILE}
    #channelName=$(echo ${line}|awk 'BEGIN{FS="/"}{print $(NF-1)}')
    eval $(echo ${line}|awk 'BEGIN{FS="/"}{printf("dir2=%s; channelName=%s;",$(NF-1),$NF)}')
    lenLine=${#line}
    lenDir2=${#dir2}
    lenChannelName=${#channelName}
    lenDir1=$(($lenLine-$lenChannelName-$lenDir2-1))
    dir1=${line:0:$lenDir1}

    for i in $(seq ${startCh0} ${numCh0})
    do
        tDir2="d"${i}
        if [[ $tDir2 != $dir2 ]]; then
            filePath=${dir1}${tDir2}"/"${channelName:0:$(($lenChannelName-1))}${i}"_0003.mat"

            if [ -e $filePath ]; then
                echo ${dir1}${tDir2}"/"${channelName:0:$(($lenChannelName-1))}${i} >> ${All_ID_FILE}
            fi 
        fi
    done
done < ${PART_ID_FILE0}

dir1=/media/radarops/
dir2=./d8/
channelName=Channel
while IFS='' read -r line || [[ -n "$line" ]]; do

    echo "${line}" >> ${All_ID_FILE}
    #channelName=$(echo ${line}|awk 'BEGIN{FS="/"}{print $(NF-1)}')
    eval $(echo ${line}|awk 'BEGIN{FS="/"}{printf("dir2=%s; channelName=%s;",$(NF-1),$NF)}')
    lenLine=${#line}
    lenDir2=${#dir2}
    lenChannelName=${#channelName}
    lenDir1=$(($lenLine-$lenChannelName-$lenDir2-1))
    dir1=${line:0:$lenDir1}

    for i in $(seq ${startCh1} ${numCh1})
    do
        tDir2="d"${i}
        i1=$(($i-8))
        if [[ $tDir2 != $dir2 ]]; then
            filePath=${dir1}${tDir2}"/"${channelName:0:$(($lenChannelName-1))}${i1}"_0003.mat"

            if [ -e $filePath ]; then
                echo ${dir1}${tDir2}"/"${channelName:0:$(($lenChannelName-1))}${i1} >> ${All_ID_FILE}
            fi 
        fi
    done
done < ${PART_ID_FILE1}

if [ -f ${All_ID_FILE} ]; then
    echo -n "${All_ID_FILE} has lines at number " 
    wc -l ${All_ID_FILE}
fi

if [ -e $LINE_NO_FILE ]; then
    rm -f $LINE_NO_FILE
    touch ${LINE_NO_FILE}
else 
    touch ${LINE_NO_FILE}
fi

while IFS='' read -r line || [[ -n "$line" ]]; do
        eval "ls $line*.mat | wc -l >> ${LINE_NO_FILE}";
done < ${All_ID_FILE}

echo "exit gracefully"
