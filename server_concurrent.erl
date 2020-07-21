-module(server_concurrent).

-export([initialize/0, initialize_with/3, init_concurrent_server/3]).

-include_lib("eunit/include/eunit.hrl").

initialize() ->
    PID = initialize_with(dict:new(), sets:new(), dict:new()),
    PID.

initialize_with(Users, LoggedIn, Channels) ->
    ServerPid = spawn_link(?MODULE, init_concurrent_server, [Users, LoggedIn, Channels]),
    catch unregister(server_actor),
    register(server_actor, ServerPid),
    ServerPid.


% Channels is a dict {channelname : PID}; Benchmarks is a dict {name:message history};
% Users is a dict with {name : subs}.

init_concurrent_server(Users, LoggedIn, Channels) ->
	Channels_PID = dict:map(
        fun (_, {channel, Name, Messages}) -> 
                PID = spawn_link(channel, init_channel_actor, [Name, dict:new(), [], Messages]),
                PID
                end, 
                Channels),
	dict:map(
		fun (_, {user, Name, Subscriptions}) ->
			    Subs = sets:to_list(Subscriptions),
			    register_user_to_channels(Name, Subs, Channels_PID)
		        end, Users),
	
    UsersSet = sets:from_list(dict:fetch_keys(Users)),
	server_actor(UsersSet, LoggedIn, Channels_PID).

register_user_to_channels(User, Channels, Channels_PID) ->
	lists:foreach(
		fun (Channel) ->
			register_user_to_channel(User, Channel, Channels_PID)
		end, Channels).

register_user_to_channel(User, Channel, Channels) ->
	Channel_Process = dict:fetch(Channel, Channels),
	Channel_Process ! {self(), register, User}.

broadcast(Channels, Message) ->
	% StartTime = os:timestamp(),
	dict:map(fun (_, PID) -> PID ! Message end, Channels).
	% Time = timer:now_diff(os:timestamp(), StartTime),
	% io:format("Channel broadcast time = ~p ms~n",
 %        [Time / 1000.0]).

send_msg_to_channel(Channel, Channels, Message) ->
	case dict:find(Channel, Channels) of
		{ok, PID} 	-> 	PID ! Message,
						Channels;
		error 		-> 	PID = spawn_link(channel, init_channel_actor, [Channel, dict:new(), [], []]),
						PID ! Message,
						NewChannels = dict:store(Channel, PID, Channels),
						NewChannels
	end.

server_actor(Users, LoggedIn, Channels) ->
	receive
		{Sender, register_user, UserName} ->
			New_Users = sets:add_element(UserName, Users),
			New_LoggedIn = sets:add_element(UserName, LoggedIn), %% new users are logged in
			Sender ! {self(), user_registered},
			server_actor(New_Users, New_LoggedIn, Channels);

		{Sender, log_in, UserName} ->
			New_LoggedIn = sets:add_element(UserName, LoggedIn),
			Sender ! {self(), logged_in},
			broadcast(Channels, {self(), login, UserName, Sender}),
			server_actor(Users, New_LoggedIn, Channels);

		{Sender, log_out, UserName} ->
			New_LoggedIn = sets:del_element(UserName, LoggedIn),
			broadcast(Channels, {self(), logout, UserName, Sender}),
			server_actor(Users, New_LoggedIn, Channels);

		{Sender, join_channel, UserName, ChannelName} ->
			NewChannels = send_msg_to_channel(ChannelName, Channels, {Sender, register, UserName}), 
			server_actor(Users, LoggedIn, NewChannels);

		{Sender, send_message, UserName, ChannelName, MessageText, SendTime} ->
			NewChannels = send_msg_to_channel(ChannelName, Channels, {Sender, send_message, UserName, MessageText, SendTime}),
			server_actor(Users, LoggedIn, NewChannels);

		{Sender, get_channel_history, ChannelName} ->
			NewChannels = send_msg_to_channel(ChannelName, Channels, {Sender, history}),
			server_actor(Users, LoggedIn, NewChannels);

		{Sender, members, ChannelName} ->
			NewChannels = send_msg_to_channel(ChannelName, Channels, {Sender, members}),
			server_actor(Users, LoggedIn, NewChannels);		

		{Sender, logged_in, ChannelName} ->
			NewChannels = send_msg_to_channel(ChannelName, Channels, {Sender, logged_in}),
			server_actor(Users, LoggedIn, NewChannels);	

		{Sender, channels} ->
			Sender ! {self(), channels, Channels},
			server_actor(Users, LoggedIn, Channels);				

		_Other -> 
			server_actor(Users, LoggedIn, Channels)
	end.