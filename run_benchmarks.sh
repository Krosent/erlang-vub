for i in {1..8}
do
    for j in {1..30}
    do
        echo "> Benchmark has been started, on $i core(s), $j iteration"
    	erl +S $i -noshell -s bench run_bench -s init stop >> benchs/output-bench-$i.txt
    done
done
