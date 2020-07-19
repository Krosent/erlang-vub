-module(client).

-export([client/3]).

% TODO: Modify
client(UserName, Server, register) ->
	Server ! {self(), register_user, UserName},
	receive
		{_S, user_registered} ->
			client_actor(UserName, dict:new(), Server, [])
	end;

% TODO: Modify
client(UserName, Server, login) ->
	Server ! {self(), log_in, UserName},
	receive
		{_Serv, logged_in} ->
		client_actor(UserName, dict:new(), Server, [])
	end.


client_actor(UserName, Channels, Server, Messages) ->
	receive
		{_Client, send_message, ChannelName, MessageText} ->
			SendTime = os:system_time(),
			Message = {message, UserName, ChannelName, MessageText, SendTime},
			ChannelMsg = {self(), send_message, UserName, MessageText, SendTime},
			send_message(ChannelName, Channels, ChannelMsg, 5),
			client_actor(UserName, Channels, Server, Messages ++ [Message]);

		{_ChannelID, new_message, {message, User, ChannelName, MessageText, SendTime}} ->
			% io:fwrite("~p - [~p]~p: ~p~n", [SendTime, ChannelName, User, MessageText]),
			client_actor(UserName, Channels, Server, Messages ++ [{message, User, ChannelName, MessageText, SendTime}]);

		{ChannelID, channel_joined, ChannelName, ChannelMessages} ->
			% io:fwrite("Channel joined~n"),
			NewChannels = join_channel(ChannelName, ChannelID, Channels),
			NewMessages = lists:merge(ChannelMessages, Messages),
			client_actor(UserName, NewChannels, Server, NewMessages);

		{Client, join_channel, ChannelName} ->
			% io:fwrite("join_channel~n"),
			Server ! {self(), join_channel, UserName, ChannelName},
			Client ! {self(), join_successful},
			client_actor(UserName, Channels, Server, Messages);

		{Client, channels} ->
			ChannelNames = dict:fetch_keys(Channels),
			Client ! {self(), channels, ChannelNames},
			client_actor(UserName, Channels, Server, Messages);

		{Client, history} ->
			Client ! {self(), history, Messages},
			client_actor(UserName, Channels, Server, Messages);

		{Client, logout} ->
			Server ! {self(), log_out, UserName},
			ChannelNames = dict:fetch_keys(Channels),
			log_out(Client, ChannelNames);
			% clientloop(UserName, Channels, Server, Messages);

		_Other ->
			% io:fwrite("Client Other: ~p~n", [Other]),
			client_actor(UserName, Channels, Server, Messages)
	end.



join_channel(Name, ChannelID, Channels) ->
	case dict:find(Name, Channels) of
		{ok, _Value} ->
			Channels;
		error ->
			NewChannels = dict:store(Name, ChannelID, Channels),
			NewChannels
	end.

send_message(_, _, _, 0) -> false;
send_message(ChannelName, Channels, Message, X) ->
	case dict:find(ChannelName, Channels) of
		{ok, ChannelID} ->
			% io:fwrite("send message ~p~p : ~p~n", [ChannelName, ChannelID, Message]),
			ChannelID ! Message,
			true;
		error ->
			timer:sleep(250),
			send_message(ChannelName, Channels, Message, X - 1)
			% io:fwrite("You didn't actually believe this would work, did you?~n")
			% false
	end.

log_out(Client, []) -> Client ! {self(), logged_out};
log_out(Client, Channels) ->
	receive
		{_ClientID, channel_logged_out, ChannelName} ->
			Reduced = lists:delete(ChannelName, Channels),
			log_out(Client, Reduced);
		_Other ->
			log_out(Client, Channels)
	end.



% client_run() ->
% 	{ok, [Value]} = io:fread("username > ", "~s").