#!/bin/sh

# To be run in /Users/jclune/Desktop/17 Provers max_facts_probs/FOF_0256

totalDuperMinus=0
solvedDuperMinus=0

for file in $(cat all_problems.txt) 
do
	if [[ $file == *".p" ]]
	then
		bushyfile=vampire_bushy/"${file:2}" # Remove prefix './' and replace it with prefix 'vampire_bushy/'
		echo "Calling Duper on $bushyfile"
		# Give each problem a 30s time limit
		res=$((timeout 30s /Users/jclune/Desktop/duper/.lake/build/bin/duper $bushyfile) || echo "Duper timed out on $bushyfile")
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_vampire_bushy_FOF_0256_results1_redo.txt
		totalDuperMinus=$((totalDuperMinus+1))
		if [[ $res == *"SZS status Theorem"* ]]
		then
			solvedDuperMinus=$((solvedDuperMinus+1))	
		fi
		echo "Number attempted so far (Duper-): $totalDuperMinus, number solved so far: $solvedDuperMinus"
	fi	
done

echo "Number attempted in total (Duper-): $totalDuperMinus, number solved in total: $solvedDuperMinus"
echo "Number attempted in total (Duper-): $totalDuperMinus, number solved in total: $solvedDuperMinus" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_vampire_bushy_FOF_0256_summary_results.txt

totalDuperPlus=0
solvedDuperPlus=0

for file in $(cat all_problems.txt) 
do
	if [[ $file == *".p" ]]
	then
		bushyfile=vampire_bushy/"${file:2}" # Remove prefix './' and replace it with prefix 'vampire_bushy/'
		echo "Calling Duper on $bushyfile"
		# Give each problem a 30s time limit
		res=$((timeout 30s /Users/jclune/Desktop/duper/.lake/build/bin/duperPlus $bushyfile) || echo "Duper timed out on $bushyfile")
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_vampire_bushy_FOF_0256_results2.txt
		totalDuperPlus=$((totalDuperPlus+1))
		if [[ $res == *"SZS status Theorem"* ]]
		then
			solvedDuperPlus=$((solvedDuperPlus+1))	
		fi
		echo "Number attempted so far (Duper+): $totalDuperPlus, number solved so far: $solvedDuperPlus"
	fi	
done

echo "Number attempted in total (Duper+): $totalDuperPlus, number solved in total: $solvedDuperPlus"
echo "Number attempted in total (Duper+): $totalDuperPlus, number solved in total: $solvedDuperPlus" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_17_vampire_bushy_FOF_0256_summary_results.txt

# totalMetis=0
# solvedMetis=0

# for file in $(cat all_problems.txt) 
# do
# 	if [[ $file == *".p" ]]
# 	then
# 		bushyfile=vampire_bushy/"${file:2}" # Remove prefix './' and replace it with prefix 'vampire_bushy/'
# 		echo "Calling Metis on $bushyfile"
# 		# Give each problem a 30s time limit
# 		res=$((timeout 30s /Users/jclune/Desktop/metis/bin/mlton/metis --time-limit 30 $bushyfile) || echo "Metis timed out on $bushyfile") 
# 		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/metis_17_vampire_bushy_FOF_0256_results.txt
# 		totalMetis=$((totalMetis+1))
# 		if [[ $res == *"SZS status Theorem"* ]]
# 		then
# 			solvedMetis=$((solvedMetis+1))	
# 		fi
# 		echo "Number attempted so far (Metis): $totalMetis, number solved so far: $solvedMetis"
# 	fi	
# done

# echo "Number attempted in total (Metis): $totalMetis, number solved in total: $solvedMetis"
# echo "Number attempted in total (Metis): $totalMetis, number solved in total: $solvedMetis" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/metis_17_vampire_bushy_FOF_0256_summary_results.txt
