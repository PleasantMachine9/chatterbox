-module(http2_frame_headers).

-include("http2.hrl").

-behaviour(http2_frame).

-export([read_payload/2,send/3]).

-spec read_payload(socket() | binary(), frame_header()) -> {ok, payload()} | {error, term()}.
read_payload(SocketOrBin, Header) ->
    {Data, Rem} = http2_padding:read_possibly_padded_payload(SocketOrBin, Header),
    {Priority, HeaderFragment} = case is_priority(Header) of
        true ->
            http2_frame_priority:read_priority(Data);
        false ->
            {undefined, Data}
    end,

    Payload = #headers{
                 priority=Priority,
                 block_fragment=HeaderFragment
                },

    lager:debug("HEADERS payload: ~p", [Payload]),
    {ok, Payload, Rem}.

is_priority(#header{flags=F}) when F band ?FLAG_PRIORITY == 1 ->
    true;
is_priority(_) ->
    false.

%% TODO: Pretty hardcoded and gross
send({Transport, Socket}, StreamId, Data) ->
    L = byte_size(Data),
    Transport:send(Socket, [<<L:24,?HEADERS:8,?FLAG_END_HEADERS:8,0:1,StreamId:31>>,Data]).