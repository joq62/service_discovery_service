%%% -------------------------------------------------------------------
%%% Author  : uabjle
%%% Description : dbase using dets 
%%% 
%%% Created : 10 dec 2012
%%% -------------------------------------------------------------------
-module(sd_service_tests).  
   
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include_lib("eunit/include/eunit.hrl").
%% --------------------------------------------------------------------

%% External exports
-export([start/0]).



%% ====================================================================
%% External functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function:tes cases
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------
start()->
    spawn(fun()->eunit:test({timeout,10*60,sd_service}) end).

cases_test()->
    ?debugMsg("Test system setup"),
    ?assertEqual(ok,setup()),

    %% Start application tests
    
    
    ?debugMsg("sd  test "),
    ?assertEqual(ok,sd_test:start()),


    ?debugMsg("Start stop_test_system:start"),
    %% End application tests
    cleanup(),
    ok.


%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
setup()->
    ?assertEqual(ok,rpc:call('node1@asus',application,start,[sd_service])),
    %timer:sleep(200),	
    
   ?assertEqual({pong,node1@asus,sd_service},rpc:call('node1@asus',sd_service,ping,[])),
    ?assertEqual(ok,application:start(sd_service)),

    ok.

cleanup()->
    application:stop(sd_service),
    rpc:call('node1@asus',init,stop,[]),
    init:stop().




