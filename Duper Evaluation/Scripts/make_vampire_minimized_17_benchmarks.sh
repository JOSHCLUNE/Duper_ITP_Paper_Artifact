# To be run in /Users/jclune/Desktop/17 Provers max_facts_probs/FOF_0256 (or any 17 Provers subdirectory)

total=0
solved=0

for file in $(cat all_problems.txt)
do
	if [[ $file == *".p" ]]
	then
		clean_file=clean/"${file:2}"
		vampire_hyps_file=vampire_hyps/"${file:2}"
		vampire_bushy_file=vampire_bushy/"${file:2}"
		echo "Creating vampire bushy file of $clean_file"
		res=$((timeout 30s /Users/jclune/Desktop/lean-auto/build/bin/defaultExe $clean_file $vampire_hyps_file $vampire_bushy_file) || echo "Vampire timed out on $clean_file")
		echo $res
		total=$((total+1))
		if [[ $res == "Vampire solved"* ]]
		then
			solved=$((solved+1))
		fi
		echo "Number attempted so far: $total, number solved so far: $solved"
	fi
done

echo "Number attempted in total: $total, number solved in total: $solved"
