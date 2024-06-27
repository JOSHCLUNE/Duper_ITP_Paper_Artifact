#!/bin/sh

# To be run in /Users/jclune/Desktop/17 Provers max_facts_probs/FOF_0016

totalMinus=0
solvedMinus=0

for file in $(cat all_problems.txt) 
do
	if [[ $file == *".p" ]]
	then
		bushyfile=bushy/"${file:2}" # Remove prefix './' and replace it with prefix 'bushy/'
		echo "Calling Duper(-) on $bushyfile"
		# Give each problem a 30s time limit
		res=$((timeout 30s /Users/jclune/Desktop/duper/.lake/build/bin/duper $bushyfile) || echo "Duper timed out on $bushyfile")
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_bushy_FOF_0016_results1.txt
		totalMinus=$((totalMinus+1))
		if [[ $res == *"SZS status Theorem"* ]]
		then
			solvedMinus=$((solvedMinus+1))	
		fi
		echo "Number attempted so far: $totalMinus, number solved so far: $solvedMinus"
	fi	
done

echo "Number attempted in total (Duper-): $totalMinus, number solved in total: $solvedMinus"
echo "Number attempted in total (Duper-): $totalMinus, number solved in total: $solvedMinus" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_bushy_FOF_0016_summary_results.txt

totalPlus=0
solvedPlus=0

for file in $(cat all_problems.txt) 
do
	if [[ $file == *".p" ]]
	then
		bushyfile=bushy/"${file:2}" # Remove prefix './' and replace it with prefix 'bushy/'
		echo "Calling Duper(+) on $bushyfile"
		# Give each problem a 30s time limit
		res=$((timeout 30s /Users/jclune/Desktop/duper/.lake/build/bin/duperPlus $bushyfile) || echo "Duper timed out on $bushyfile")
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_bushy_FOF_0016_results2.txt
		totalPlus=$((totalPlus+1))
		if [[ $res == *"SZS status Theorem"* ]]
		then
			solvedPlus=$((solvedPlus+1))	
		fi
		echo "Number attempted so far: $totalPlus, number solved so far: $solvedPlus"
	fi	
done

echo "Number attempted in total (Duper+): $totalPlus, number solved in total: $solvedPlus"
echo "Number attempted in total (Duper+): $totalPlus, number solved in total: $solvedPlus" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_bushy_FOF_0016_summary_results.txt
