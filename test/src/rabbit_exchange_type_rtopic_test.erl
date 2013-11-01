%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ Consistent Hash Exchange.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2011-2013 GoPivotal, Inc.  All rights reserved.
%%

-module(rabbit_exchange_type_rtopic_test).
-export([test/0]).
-include_lib("amqp_client/include/amqp_client.hrl").

%% Because the routing is probabilistic, we can't really test a great
%% deal here.

test() ->
    Qs = [<<"a0.b0.c0.d0">>, <<"a1.b1.c1.d1">>],
    Publishes = [<<"a0.b0.c0.d0">>],
    Count = 1,
    ok = test0(Qs, Publishes, Count).

test0(Queues, Publishes, Count) ->
    Msg = #amqp_msg{props = #'P_basic'{}, payload = <<>>},
    {ok, Conn} = amqp_connection:start(#amqp_params_network{}),
    {ok, Chan} = amqp_connection:open_channel(Conn),
    #'exchange.declare_ok'{} =
        amqp_channel:call(Chan,
                          #'exchange.declare' {
                            exchange = <<"rtopic">>,
                            type = <<"x-rtopic">>,
                            auto_delete = true
                           }),
    [#'queue.declare_ok'{} =
         amqp_channel:call(Chan, #'queue.declare' {
                             queue = Q, exclusive = true }) || Q <- Queues],
    [#'queue.bind_ok'{} =
         amqp_channel:call(Chan, #'queue.bind' { queue = Q,
                                                 exchange = <<"rtopic">>,
                                                 routing_key = Q })
     || Q <- Queues],
     
    #'tx.select_ok'{} = amqp_channel:call(Chan, #'tx.select'{}),
    [amqp_channel:call(Chan, #'basic.publish'{
                        exchange = <<"rtopic">>, routing_key = RK},
                       Msg) || RK <- Publishes],
    amqp_channel:call(Chan, #'tx.commit'{}),
     
    Counts =
        [begin
            #'queue.declare_ok'{message_count = M} =
                 amqp_channel:call(Chan, #'queue.declare' {queue     = Q,
                                                           exclusive = true }),
             M
         end || Q <- Queues],
    Count = lists:sum(Counts), %% All messages got routed
    amqp_channel:call(Chan, #'exchange.delete' { exchange = <<"rtopic">> }),
    [amqp_channel:call(Chan, #'queue.delete' { queue = Q }) || Q <- Queues],
    amqp_channel:close(Chan),
    amqp_connection:close(Conn),
    ok.