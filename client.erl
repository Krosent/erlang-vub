-module(client).

-export([client_register/2, client_auth/2]).

% TODO: Modify
client_register(UserName, Server) ->
	Server ! {self(), register_user, UserName},
	receive
		{_S, user_registered} ->
			client_actor(UserName, dict:new(), Server, [])
	end.

% TODO: Modify
client_auth(UserName, Server) ->
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

		_Other ->
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
			ChannelID ! Message,
			true;
		error ->
			timer:sleep(250),
			send_message(ChannelName, Channels, Message, X - 1)
	end.

log_out(Client, []) -> Client ! {self(), logged_out};
log_out(Client, Channels) ->
	receive
		{_ClientID, channel_logged_out, ChannelName} ->
			ChannelsListWithoutRemoved = lists:delete(ChannelName, Channels),
			log_out(Client, ChannelsListWithoutRemoved);
		_Other ->
			log_out(Client, Channels)
	end.