for i in {1..4}
do
    #echo "---"
    #echo "> fib, $i threads"
    #erl +S $i -noshell -s benchmark test_fib -s init stop > output-fib-$i.txt
    #echo "---"
    #echo "> get_channel_history, $i threads"
    #erl +S $i -noshell -s benchmark test_get_channel_history -s init stop > output-get_channel_history-$i.txt
    echo "---"
    echo "> Test #1, $i threads"
    erl +S $i -noshell -s benchmark test_send_message_custom -s init stop > output-test1-$i.txt
    echo "---"
    echo "> Test #2, $i threads"
    erl +S $i -noshell -s benchmark test_send_message_500 -s init stop > output-test2-$i.txt
    echo "---"
    echo "> Test #3, $i threads"
    erl +S $i -noshell -s benchmark test_register_and_login -s init stop > output-test3-$i.txt
done
