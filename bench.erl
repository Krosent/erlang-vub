-module(bench).
-export([run_bench/0, wait_for_messages/2]).

initialize_server() ->
	catch unregister(server_actor),
	server_concurrent:initialize().

register_user(NumberOfMember, NumberOfChannels) ->
	io:fwrite("--- Register users --- ~n"),
	
    StartTime = os:timestamp(), % Wall clock time

	ClientsList = lists:map(
		fun(I) ->
			ClientID = spawn(client, client_register, [I, server_actor]),
			ClientID ! {self(), join_channel, I rem NumberOfChannels},
			receive
				{ClientID, join_successful} ->
					{I, ClientID}
					end
				end, lists:seq(1, NumberOfMember)),

	Clients = dict:from_list(ClientsList),

	dict:map(
		fun (_I, ClientID) ->
			ClientID ! {self(), logout},
			receive
				{_S1, logged_out} ->
				ok
				end
			end, Clients),

    Time = timer:now_diff(os:timestamp(), StartTime),
    io:format("Wall clock time =[RU] ~p ms~n",
        [Time / 1000.0]),
    Clients.

auth_users(NumberOfUsers) ->
	io:fwrite("--- Users Authorization --- ~n"),
	
    StartTime = os:timestamp(),

	UsersList = lists:map(
		fun(I) -> 
			ClientID = spawn(client, client_auth, [I, server_actor]),
			{I, ClientID}
			end, lists:seq(1, NumberOfUsers)
		),
	Users = dict:from_list(UsersList),

    Time = timer:now_diff(os:timestamp(), StartTime),
    io:format("Wall clock time =[AU] ~p ms~n",
        [Time / 1000.0]),
    Users.

send_messages(Users, NumberOfChannels, MessagesPerUser) ->
	io:fwrite("--- Send Messages To Users --- ~n"),
	
    StartTime = os:timestamp(), % Wall clock time

	dict:map(fun (I, PID) ->
				lists:foreach(fun (_J) ->
					PID ! {self(), send_message, I rem NumberOfChannels, "Checking in."}
				end, lists:seq(1, MessagesPerUser))
			 end, Users),
	
	dict:map(fun (_I, PID) ->
				PID ! {self(), channels},
				receive
					{_S1, channels, [Channel]} ->
						ok
				end,
				server_actor ! {self(), channels},
				receive
					{_S2, channels, ChannelsDict} ->
						ok
				end,
				{ok, ChannelID} = dict:find(Channel, ChannelsDict),
				ChannelID ! {self(), logged_in},
				receive
					{_S3, logged_in, Logged_in} ->
						ok
				end,
				Size = length(Logged_in) * MessagesPerUser,
				wait_for_messages(PID, Size)
			 end, Users),
	
    Time = timer:now_diff(os:timestamp(), StartTime),
    io:format("Wall clock time =[SM] ~p ms~n",
        [Time / 1000.0]).

wait_for_messages(PID, NumberOfMessages) ->
	PID ! {self(), history},
	receive
		{_Serv, history, Messages} ->
			Len = length(Messages),
			if Len >= NumberOfMessages
					-> ok;
			true 	->
				wait_for_messages(PID, NumberOfMessages)
			end
	end.

get_channel_history() ->
	io:fwrite("--- Receive History --- ~n"),

    StartTime = os:timestamp(), % Wall clock time

	server_actor ! {self(), channels},

	receive
		{_Serv, channels, Channels} ->
			ok
	end,

	ChannelsSize = dict:size(Channels),

	dict:map(fun (_I, PID) ->
				PID ! {self(), history}
			 end, Channels),

	wait_for_history(ChannelsSize),
	
    Time = timer:now_diff(os:timestamp(), StartTime),
    io:format("Wall clock time =[GH] ~p ms~n",
        [Time / 1000.0]).

wait_for_history(0) -> ok;
wait_for_history(X) ->
	receive
		{_Channel, channel_history, _Messages} ->
			wait_for_history(X - 1)
	end.

run_bench() ->
	io:fwrite("--- Start Benchmarking --- ~n"),
	% Register N amount of users per M amount of channels.
	% Send to Users in M number of channels Z number of messages.
	initialize_server(),
	register_user(5000, 10),
	Users = auth_users(1000),
	timer:sleep(1000),
	send_messages(Users, 10, 2),
	get_channel_history(),

	io:fwrite("--- End of Benchmarking --- ~n").