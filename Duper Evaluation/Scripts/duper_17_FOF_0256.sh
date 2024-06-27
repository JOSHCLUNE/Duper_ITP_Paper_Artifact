#!/bin/sh

# To be run in /Users/jclune/Desktop/17 Provers max_facts_probs/FOF_0256

total=0
solved=0

for file in $(cat all_problems.txt) 
do
	if [[ $file == *".p" ]]
	then
		cleanfile=clean/"${file:2}" # Remove prefix './' and replace it with prefix 'clean/'
		echo "Calling Duper(-) on $cleanfile"
		# Give each problem a 30s time limit
		res=$((timeout 30s /Users/jclune/Desktop/duper/.lake/build/bin/duper $cleanfile) || echo "Duper timed out on $cleanfile")
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_FOF_0256_results1.txt
		total=$((total+1))
		if [[ $res == *"SZS status Theorem"* ]]
		then
			solved=$((solved+1))	
		fi
		echo "Number attempted so far: $total, number solved so far: $solved"
	fi	
done

echo "Number attempted in total (Duper-): $total, number solved in total: $solved"
echo "Number attempted in total (Duper-): $total, number solved in total: $solved" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_FOF_0256_summary_results1.txt
