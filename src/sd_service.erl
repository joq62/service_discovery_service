%%% -------------------------------------------------------------------
%%% @author  : Joq Erlang
%%% @doc: : 
%%%  
%%% Created : 10 dec 2012
%%% -------------------------------------------------------------------
-module(sd_service). 

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("timeout.hrl").
-include("log.hrl").
%-include("config.hrl").
%% --------------------------------------------------------------------


%% --------------------------------------------------------------------
%% Key Data structures
%% 
%% --------------------------------------------------------------------
-record(state, {local_services,
                external_services}).


%% --------------------------------------------------------------------
%% Definitions 
%% --------------------------------------------------------------------



-export([add_service/1,remove_service/1,fetch_service/1,
	 trade_services/0,trade_services/2,
	 fetch_all/1
	]).

-export([start/0,
	 stop/0,
	 ping/0,
	 heart_beat/1
	]).

%% gen_server callbacks
-export([init/1, handle_call/3,handle_cast/2, handle_info/2, terminate/2, code_change/3]).


%% ====================================================================
%% External functions
%% ====================================================================

%% Asynchrounus Signals



%% Gen server functions

start()-> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
stop()-> gen_server:call(?MODULE, {stop},infinity).


ping()-> 
    gen_server:call(?MODULE, {ping},infinity).

%%-----------------------------------------------------------------------


fetch_service(ServiceId) ->
    gen_server:call(?MODULE, {fetch_service, ServiceId}).
fetch_all(ServiceList) ->
    gen_server:call(?MODULE, {fetch_all, ServiceList}).


%%----------------------------------------------------------------------

add_service(ServiceId) ->
    gen_server:cast(?MODULE, {add_service, ServiceId}).
remove_service(ServiceId) ->
    gen_server:cast(?MODULE, {remove_service,ServiceId}).
trade_services() ->
    gen_server:cast(?MODULE, {trade_services}).
trade_services(Node,ExportedServiceList) ->
    gen_server:cast(?MODULE, {trade_services,Node,ExportedServiceList}).
heart_beat(Interval)->
    gen_server:cast(?MODULE, {heart_beat,Interval}).


%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%
%% --------------------------------------------------------------------
init([]) ->
    spawn(fun()->h_beat(?VM_HEARTBEAT) end),
       {ok, #state{local_services=[],
                external_services=[]}}.
    
%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (aterminate/2 is called)
%% --------------------------------------------------------------------
handle_call({ping},_From,State) ->
    Reply={pong,node(),?MODULE},
    {reply, Reply, State};

handle_call({fetch_service, WantedServiceId}, _From, State) ->
    AllServices=lists:append(State#state.local_services,State#state.external_services),
    Reply=[Node||{ServiceId,Node}<-AllServices,
		 WantedServiceId==ServiceId],
    {reply,Reply, State};

handle_call({fetch_all, local_services}, _From, State) ->
    Reply=State#state.local_services,
    {reply,Reply, State};
handle_call({fetch_all, external_services}, _From, State) ->
    Reply=State#state.external_services,
    {reply,Reply, State};
handle_call({fetch_all, all}, _From, State) ->
    Reply=lists:append(State#state.local_services,State#state.external_services),
    {reply,Reply, State};


handle_call({stop}, _From, State) ->
    {stop, normal, shutdown_ok, State};

handle_call(Request, From, State) ->
    Reply = {unmatched_signal,?MODULE,Request,From},
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% -------------------------------------------------------------------
handle_cast({heart_beat,Interval}, State) ->
    spawn(fun()->h_beat(Interval) end),    
    {noreply, State};

handle_cast({add_service, ServiceId}, State) ->
    NewState=State#state{local_services=lists:usort([{ServiceId,node()}|State#state.local_services])},
    {noreply,NewState};

handle_cast({remove_service, ServiceId}, State) ->
    NewState=State#state{local_services=lists:delete({ServiceId,node()},State#state.local_services)},
    {noreply,NewState};

handle_cast({trade_services}, State) ->
    LocalServicesList = State#state.local_services,
    LocalNode=node(),
    AllNodes = [LocalNode | nodes()],
    [rpc:cast(Node,sd_service,trade_services,[LocalNode,LocalServicesList])||
	Node<-AllNodes],
    {noreply, State};

handle_cast({trade_services,ReplyTo, ExternalServiceList},
	    #state{local_services = LocalServiceList,
		   external_services = OldExternalServiceList} = State) ->
    case ReplyTo of
        noreply ->
            ok;
        _ ->
            rpc:cast(ReplyTo,sd_service,trade_services,[noreply, LocalServiceList])
    end,
    NewState=State#state{external_services=lists:usort(lists:append(ExternalServiceList,OldExternalServiceList))},
    {noreply, NewState};
			     

handle_cast(Msg, State) ->
    io:format("unmatched match cast ~p~n",[{?MODULE,?LINE,Msg}]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------

handle_info(Info, State) ->
    io:format("unmatched match info ~p~n",[{?MODULE,?LINE,Info}]),
    {noreply, State}.


%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------
%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
h_beat(Interval)->
    sd_service:trade_services(),
    timer:sleep(Interval),
    rpc:cast(node(),?MODULE,heart_beat,[Interval]).

%% --------------------------------------------------------------------
%% Internal functions
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
