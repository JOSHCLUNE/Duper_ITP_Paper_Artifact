# To be run in /Users/jclune/Desktop/17 Provers max_facts_probs/TH0_MINUS_0016

total=0
solved=0

for file in $(cat all_problems.txt)
do
	if [[ $file == *".p" ]]
	then
		clean_file=clean/"${file:2}"
		zipperposition_solution_file=zipperposition_solution/"${file:2}"
		bushy_file=bushy/"${file:2}"
		res=$((timeout 30s /Users/jclune/Desktop/lean-auto/build/bin/defaultExe $clean_file $zipperposition_solution_file $bushy_file) || echo "Zipperposition timed out on $clean_file")
		echo $res
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/zipperposition_17_TH0_MINUS_0016_results.txt
		total=$((total+1))
		if [[ $res == "Zipperposition solved"* ]]
		then
			solved=$((solved+1))
		fi
		echo "Number attempted so far: $total, number solved so far: $solved"
	fi
done

echo "Number attempted in total: $total, number solved in total: $solved"
echo "Number attempted in total: $total, number solved in total: $solved" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/zipperposition_17_TH0_MINUS_0016_summary_results.txt
