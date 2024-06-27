#!/bin/sh

# To be run in /Users/jclune/Desktop/17 Provers max_facts_probs/FOF_0016 

for file in $(cat all_problems.txt) 
do
	if [[ $file == *".p" ]]
	then
		cleanfile=clean/"${file:2}" # Remove prefix './' and replace it with prefix 'clean/'
		# Rewrite file without comments to cleanfile
		(sed '/^[[:blank:]]*%/d;s/%.*//' $file | awk '{$1=$1};1') > $cleanfile
	fi	
done

echo "Done"
