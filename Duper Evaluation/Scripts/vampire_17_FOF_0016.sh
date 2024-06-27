# To be run in /Users/jclune/Desktop/17 Provers max_facts_probs/FOF_0016

total=0
solved=0

for file in $(cat all_problems.txt)
do
	if [[ $file == *".p" ]]
	then
		clean_file=clean/"${file:2}"
		vampire_solution_file=vampire_solution/"${file:2}"
		echo "Calling vampire on $clean_file"
		res=$((timeout 30s /Users/jclune/Desktop/lean-auto/build/bin/defaultExe $clean_file $vampire_solution_file) || echo "Vampire timed out on $clean_file")
		echo $res
		echo $res >> /Users/jclune/Desktop/Duper\ Evaluation/Results/vampire_17_FOF_0016_results.txt
		total=$((total+1))
		if [[ $res == "Vampire solved"* ]]
		then
			solved=$((solved+1))
		fi
		echo "Number attempted so far: $total, number solved so far: $solved"
	fi
done

echo "Number attempted in total: $total, number solved in total: $solved"
echo "Number attempted in total: $total, number solved in total: $solved" >> /Users/jclune/Desktop/Duper\ Evaluation/Results/vampire_17_FOF_0016_summary_results.txt
