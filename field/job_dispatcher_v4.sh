#!/bin/bash 

#To run: ./job_dispatcher_v2.sh /media/radarops 16
#where /media/radrops is location of drives and 16 is number of drives
#assumes this is inside a directory named field

i=0
dat_array=()
parent_dir=$1'/'	#this is the location of the storage drives
count=0

declare -A dict_xml

scan_for_xml() {
	cd $parent_dir
	
	if [ -d $parent_dir ]; then	#if the folder exists
		for f in $(find "$PWD" -type f | grep 'config.xml'); do
			time_stamp_xml=`echo $f | sed 's#.*/##g'`
			time_stamp_xml=${time_stamp_xml:0:16}
			if [ -z ${dict_xml[$time_stamp_xml]} ]; then
				dict_xml+=([$time_stamp_xml]=$f)
			fi
		done
	else
		echo $parent_dir does not exist
		exit 1
	fi
}


###Done with XML

add_dat_files() {
	local counter=0
	local head_pos=1
	local curr_path=$0$1

	if [ ! -d "$curr_path" ]; then
		echo $curr_path does not exist
		exit 1
	fi

	cd $curr_path
	
	while [ $head_pos != -1 ]; do
		local curr_file=$(find "$PWD" -type f | head -$head_pos | tail -1)
		local prev_file=$(find "$PWD" -type f | head -$(($head_pos - 1)) | tail -1)
		local mat_equiv=${curr_file/.dat/.mat}		

		if [ "$curr_file" == "$prev_file" ]; then	#special case for when you're at the last file in directory
			unset curr_file
		fi

		if [ -z "$curr_file" ]; then		#if curr_file has been unset/doesn't exist
			head_pos=-1
		else
			if [ "${curr_file: -3}" == "dat" ] && [ ! -f $mat_equiv  ]; then	#add if its a .dat file
				echo $2%$curr_file
				((counter++))
			fi
			((head_pos++))
		fi
	done
}


if [ -f "xml.log" ]; then
	echo Removing old xml.log
	rm xml.log
fi

if [ -f "new_joblist.txt" ]; then
	echo Removing new_joblist.txt
	rm new_joblist.txt
fi

if [ "$2" == "-s" ]; then		#single directory parameter
	echo Creating a joblist with .dat files only from $1
	counter=0
	cd $1
	file_array=($(ls | grep .dat))
	for each in ${file_array[@]}; do
		cd $1
		mat_equiv=${each/.dat/.mat}
		if [ "${each: -3}" == "dat" ] && [ ! -f $mat_equiv  ]; then
			timestamp=${each:0:16}
			xml_file=($(ls | grep $timestamp | grep config.xml))
			cd
			if [ ! -z $xml_file ]; then
				echo "'$1/$xml_file','$1/$each'" >> field/new_joblist.txt
			else 
				((counter++))
				echo XML file for $each does not exist >> field/xml.log
			fi
		fi
	done

	echo $counter files did not have a corresponding xml file
	echo Succesfully created new_joblist.txt
	exit 1
fi

scan_for_xml
echo xml_array Populated

drive_array=($(ls -d */))
length=${#drive_array[@]}
export -f add_dat_files

inputs=$(for idx in $(seq 0 $((length-1)))
do
	value=${drive_array[$idx]}
	echo "$parent_dir $value $idx"
done)

mapfile -t dat_array < <(echo $inputs | xargs -d' ' -P 0 -n 3 bash -c 'add_dat_files $1 $2 $3')	#runs add_dat_file on each drive concurrently and stores dat files in array

cd

declare -A multi_array	#simulates a 2d array. A array for each of the drives

for ((i=0;i<length;i++)) do
	multi_array[$i,len]=0
done


for each in ${dat_array[@]}; do	#populates the respective drive with all the data from that drive
	IFS='%' read -r curr each <<< "$each"	#to correctly split index and path using '%' 

	idx=${multi_array[$curr,len]}	
	((multi_array[$curr,len]++))
	multi_array[$curr,$idx]=$each
done


max=0
echo Populated dat files accordingly

for ((i=0;i<length;i++)) do	#finds the biggest index 
	if [ $max -lt ${multi_array[$i,len]} ]; then
		max=${multi_array[$i,len]}
	fi
done

cd

count=0;
for ((i=0;i<=max;i++)) do	#iterate thorugh all the dat files
	for ((j=0;j<length;j++)) do
		if [ $i -lt ${multi_array[$j,len]} ]; then
			dat_file=${multi_array[$j,$i]};
			time_stamp_dat=`echo $dat_file | sed 's#.*/##g'`
			time_stamp_dat=${time_stamp_dat:0:16}
	
			if [[ -z "${dict_xml[$time_stamp_dat]-}" ]]; then
				echo XML file for $dat_file does not exist >> field/xml.log
				((count++))
			else
				echo "'${dict_xml[$time_stamp_dat]}','$dat_file'" >> field/new_joblist.txt
			fi
		fi
	done
done

echo $count files did not have a corresponding xml file
echo Succesfully created new_joblist.txt
