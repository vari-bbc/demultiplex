#!/bin/bash

set -e
set -u
set -o pipefail

target_dir=$(cat RunInfo.xml|grep '<Flowcell>'|sed -e 's/<Flowcell>//'|sed -e 's/<\/Flowcell>//'|sed -e 's/ //g'| sed $'s/\r//' | sed -e 's/\s*//g')

echo "$target_dir"

 if ls $target_dir >/dev/null 2>&1; then
   echo "Target files found."
 else
   echo ""
   echo                                                                                 "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ +++++++"
   echo "WARNING: Some dmux output files do not exist. Double-check that you are in a   dmux directory."
   echo                                                                                 "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ +++++++"
   echo ""
 fi

 ls --color $target_dir || true

 echo ""

 while true; do
     read -p "Do you wish to delete the above files?" yn
     case $yn in
         [Yy]* ) echo "Ok, deleting files from previous dmux run."; break;;
         [Nn]* ) echo "Ok exiting script"; exit;;
         * ) echo "Please answer yes or no.";;
     esac
 done

 rm -r $target_dir
