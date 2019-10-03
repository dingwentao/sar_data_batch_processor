#!/bin/bash
# cat << EOF
# ***ADR processes files in all folders or a single folder?**
# 1 In all folders(d0-dx)
# 2 In a folder
# EOF
# read -p "Please enter your choise: " input3
# case $input3 in
#     1) source ./job_dispatcher_v4.sh /media/radarops;;
#     2) echo "Enter folder name:"
#         read folderName
#         source source ./job_dispatcher_v4.sh ${folderName} -s 
# esac
# source ./ParallelRunScript.sh 32 new_joblist.txt

cat << EOF
***Please set the location of .mat files, reference folders, the number of channels***
1 Use the default setting (/media/radarops/; d0, d8; 8, 8)
2 Enter new location, reference folders and the number of channels 
EOF
read -p "Please enter your choise: " input0
case $input0 in
    1) location="/media/radarops/"
        refFolder0="d0"
        refFolder1="d8"
        numCh0=8
        numCh2=8
        ;;
    2) echo "Enter location, reference folder and the number of channels:"
        read location refFolder0 refFolder1 numCh0 numCh1;;
esac

cat << EOF
***Please set the size of .mat files***
1 Use the default size (1GB)
2 Enter new size
EOF
read -p "Please enter your choise: " input1
case $input1 in
    1) sizeFile=1;;
    2) echo "Enter size:"
        read sizeFile;;
esac

maxNumFiles=$((200/${sizeFile}))
cat << EOF
***Please set the number of .mat files processed in each batche and the index of first file***
1 Use the default number (100) and index (0)
2 Enter new number
EOF
read -p "Please enter your choise: " input2
case $input2 in
    1) numFile=100
        idxFirstFile=0    
        ;;
    2) echo "Enter number (max: "${maxNumFiles}") and index :"
        read numFile idxFirstFile;;
esac

echo "Start to find all the .mat files"
source ./getUniqueIds_v2.sh $location $refFolder0 $refFolder1 $numCh0 numCh1

echo "Start to execute batch SAR"
# batchSAR="batch($numFile, $idxFirstFile)"
# cmd="matlab -nodisplay -nodesktop -nosplash -r \"try; $batchSAR; catch ex; disp(ex); end; exit;\""