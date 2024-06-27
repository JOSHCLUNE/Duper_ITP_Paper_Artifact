#!/bin/sh

# To be run in /Users/jclune/Desktop/17 Provers max_facts_probs/FOF_0256 (or whichever specific 17 Provers subdirectory) 

total=0

for file in $(cat all_problems.txt) 
do
	if [[ $file == *".p" ]]
	then
		vampiresolfile=vampire_solution/"${file:2}" # Remove prefix './' and replace it with prefix 'vampire_solution/'
		vampirehypsfile=vampire_hyps/"${file:2}"
		hypsWithInput=$(grep -o '\[input .*\]' $vampiresolfile)
		# Clear vampirehypsfile first
		echo "" > $vampirehypsfile
		echo "Getting hypotheses for $file ($total of 5000 files done)"
		total=$((total+1))	
		for hyp in $hypsWithInput
		do
			if [[ "$hyp" != "[input" ]]
			then
				echo "${hyp%]}" >> $vampirehypsfile
			fi
		done
	fi	
done

echo "Done"
