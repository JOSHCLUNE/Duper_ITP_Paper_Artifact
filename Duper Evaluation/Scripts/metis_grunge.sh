#!/bin/sh

# To be run in /Users/jclune/Desktop/Grunge TrainingData.HL4

total=0
solved=0

for file in Problems/*
do
	if [[ $file == *"+1.p" ]] # Filter to only attempt FOF-I problems
	then
		# The Grunge paper gave each prover a 30s time limit
		echo "Calling metis on $file"
		res=$((timeout 30s /Users/jclune/Desktop/metis/bin/mlton/metis --time-limit 30 $file) || echo "Metis timed out on $file")
		echo $res
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/metis_grunge_results.txt
		total=$((total+1))
		if [[ $res == *"SZS status Theorem"* ]]
		then
			solved=$((solved+1))	
		fi
		echo "Number attempted so far: $total, number solved so far: $solved" 
	fi
done

echo "Number attempted in total: $total, number solved in total: $solved"
echo "Number attempted in total: $total, number solved in total: $solved" >> /Users/jclune/Desktop/Duper\ Evaluation/metis_grunge_summary_results.txt 
