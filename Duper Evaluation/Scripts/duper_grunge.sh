#!/bin/sh

# To be run in /Users/jclune/Desktop/Grunge TrainingData.HL4

totalFOF=0
solvedFOF=0

for file in Problems/*
do
	if [[ $file == *"+1.p" ]] # Filter to only attempt FOF-I problems
	then
		echo "Calling Duper(+) on $file"
		res=$((timeout 30s /Users/jclune/Desktop/duper/.lake/build/bin/duperPlus $file) || echo "Duper timed out on $file")
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_grunge_results3.txt
		totalFOF=$((totalFOF+1))
		if [[ $res == *"SZS status Theorem"* ]]
		then
			solvedFOF=$((solvedFOF+1))	
		fi
		echo "Number FOF problems attempted so far: $totalFOF, number solved so far: $solvedFOF" 
	fi
done

echo "Number FOF problems attempted in total (Duper+): $totalFOF, number solved in total: $solvedFOF"
echo "Number FOF problems attempted in total (Duper+): $totalFOF, number solved in total: $solvedFOF" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_grunge_summary_results2.txt

totalTHF=0
solvedTHF=0

for file in Problems/*
do
	if [[ $file == *"^3.p" ]] # Filter to only attempt TH0-II problems
	then
		echo "Calling Duper on $file"
		res=$((timeout 30s /Users/jclune/Desktop/duper/.lake/build/bin/duperPlus $file) || echo "Duper timed out on $file")
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_grunge_results4.txt
		totalTHF=$((totalTHF+1))
		if [[ $res == *"SZS status Theorem"* ]]
		then
			solvedTHF=$((solvedTHF+1))	
		fi
		echo "Number THF problems attempted so far: $totalTHF, number solved so far: $solvedTHF" 
	fi
done

echo "Number THF problems attempted in total (Duper+): $totalTHF, number solved in total: $solvedTHF"
echo "Number THF problems attempted in total (Duper+): $totalTHF, number solved in total: $solvedTHF" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/duper_grunge_summary_results2.txt
