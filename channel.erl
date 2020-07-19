-module(channel).

-export([init_channel_actor/4, broadcast/2]).

init_channel_actor(Name, Users, Members, Messages) ->
	channel_actor(Name, Users, Messages, Members).


% Here we represent each channel as a separate process which has own loop with different messages.
% ChannelName is a string; Users represented as a dict {name:pid}; Messages is a list; Members is a list too. 

channel_actor(ChannelName, Users, Messages, Members) ->
	% io:fwrite("Channel ~p queue length ~p~n", [ChannelName, erlang:process_info(self(), message_queue_len)]),
	receive 
		{Sender, history} ->
			Sender ! {self(), channel_history, Messages},
			channel_actor(ChannelName, Users, Messages, Members);

		{Sender, send_message, UserName, MessageText, SendTime} ->
			Message = {message, UserName, ChannelName, MessageText, SendTime},
            % UsersTo Send represent users who should receive broadcasted message. We remove sender from this list.
			UsersToSend = dict:erase(UserName, Users),
			broadcast(UsersToSend, Message),
			Sender ! {self(), message_sent},
			channel_actor(ChannelName, Users, Messages ++ [Message], Members);
			
		{_Sender, login, UserName, PID} ->
            % Login only if user is not already logged in.
			case logged_out_member_check(UserName, Users, Members) of 
				true -> 
					NewUsers = dict:store(UserName, PID, Users),
					PID ! {self(), channel_joined, ChannelName, Messages},
					channel_actor(ChannelName, NewUsers, Messages, Members);
				false ->
					channel_actor(ChannelName, Users, Messages, Members)
			end;

        {Sender, register, UserName} ->
			case lists:member(UserName, Members) of 
				true ->
					Sender ! {self(), already_member},
					channel_actor(ChannelName, Users, Messages, Members);
				false ->
					Sender ! {self(), channel_joined, ChannelName, Messages},
					NewUsers = dict:store(UserName, Sender, Users),
					channel_actor(ChannelName, NewUsers, Messages, Members ++ [UserName])
			end;

		{Sender, register, UserName, no_login} ->
			case lists:member(UserName, Members) of 
				true ->
					Sender ! {self(), already_member},
					channel_actor(ChannelName, Users, Messages, Members);
				false ->
					Sender ! {self(), channel_joined},
					channel_actor(ChannelName, Users, Messages, Members ++ [UserName])
			end;

		{_Sender, logout, UserName, Client} ->
			NewUsers = dict:erase(UserName, Users),
			Client ! {self(), channel_logged_out, ChannelName},
			channel_actor(ChannelName, NewUsers, Messages, Members);

		{Sender, members} ->
			Sender ! {self(), members, Members},
			channel_actor(ChannelName, Users, Messages, Members);

		{Sender, logged_in} ->
			Logged_in = dict:fetch_keys(Users),
			Sender ! {self(), logged_in, Logged_in},
			channel_actor(ChannelName, Users, Messages, Members);

		_Other ->
			channel_actor(ChannelName, Users, Messages, Members)
	end.

% broadcast message to selected users
broadcast(Users, Message) ->
	% StartTime = os:timestamp(),
	dict:map(fun (_, Client) ->
			Client ! {self(), new_message, Message}
		end, Users).
	% Names = dict:fetch_keys(Users).
	% io:fwrite("broadcast to : ~p~n", [Names]).
	% Time = timer:now_diff(os:timestamp(), StartTime),
	% io:format("Channel to user broadcast time = ~p ms~n",
 %    	[Time / 1000.0]).

% Logged in member verification
logged_out_member_check(UserName, Logged_in, Members)->

	case dict:find(UserName, Logged_in) of
		{ok, _Value} ->	%% already logged in
			% io:fwrite("~p is already logged in~n", [UserName]),
			false;
		error ->	%% not logged in
			case lists:member(UserName, Members) of
				true ->
					true;
				false ->
					% io:fwrite("~p is not a member~n", [UserName]),
					false
			end
	end.