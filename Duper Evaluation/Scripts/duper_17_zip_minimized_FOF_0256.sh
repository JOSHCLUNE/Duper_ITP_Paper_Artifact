#!/bin/sh

# To be run in /Users/jclune/Desktop/17 Provers max_facts_probs/FOF_0256

total=0
solved=0

for file in $(cat all_problems.txt) 
do
	if [[ $file == *".p" ]]
	then
		bushyfile=bushy/"${file:2}" # Remove prefix './' and replace it with prefix 'bushy/'
		echo "Calling Duper on $bushyfile"
		# Give each problem a 30s time limit
		res=$((timeout 30s /Users/jclune/Desktop/duper/.lake/build/bin/duper $bushyfile) || echo "Duper timed out on $bushyfile")
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_bushy_FOF_0256_results2.txt
		total=$((total+1))
		if [[ $res == *"SZS status Theorem"* ]]
		then
			solved=$((solved+1))	
		fi
		echo "Number attempted so far: $total, number solved so far: $solved"
	fi	
done

echo "Number attempted in total: $total, number solved in total: $solved"
echo "Number attempted in total: $total, number solved in total: $solved" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_bushy_FOF_0256_summary_results2.txt

