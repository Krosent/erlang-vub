for i in {1..64}
do
    echo "---"
    echo "> test_gch_custom, $i threads"
    erl +S $i -noshell -s benchmark test_get_channel_history -s init stop > output-get_channel_history-$i.txt
    echo "---"
    echo "> test_send_message_custom, $i threads"
    erl +S $i -noshell -s benchmark test_send_message -s init stop > output-send_message-$i.txt
done
