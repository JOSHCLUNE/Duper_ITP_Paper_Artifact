#!/bin/sh

# To be run in /Users/jclune/Desktop/Grunge TrainingData.HL4

total=0
solved=0

for file in Problems/*
do
	if [[ $file == *"+1.p" ]] # Filter to only attempt FOF-I problems
	then
		zipperposition_solution_file=zipperposition_solution/"$file"
		bushy_file=bushy/"$file"
		res=$((timeout 30s /Users/jclune/Desktop/lean-auto/build/bin/defaultExe $file $zipperposition_solution_file $bushy_file) || echo "Zipperposition timed out on $file")
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/zipperposition_grunge_fof1_results.txt
		echo $res
		total=$((total+1))
		if [[ $res == "Zipperposition solved"* ]]
		then
			solved=$((solved+1))
		fi
		echo "Number attempted so far: $total, number solved so far: $solved"
	fi
done

echo "Number attempted in total: $total, number solved in total: $solved"
echo "Number attempted in total: $total, number solved in total: $solved" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/zipperposition_grunge_fof1_summary_results.txt
