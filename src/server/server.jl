# implementation of the server side of the DAP using JuliaInterpreter
module Servers

using ..DebugAdapter
using ..DebugAdapter.Protocol

import SHA, MD5
using JuliaInterpreter
using JSON

@enum STATE begin
    UNINITIALIZED
    INITIALIZED
    CONFIGURED
end

mutable struct Server
    in::IO
    out::IO
    state::STATE
    last_seq::Int
    frames::Dict{Int,Frame}
    level::Int
    # broke_on_error::Bool = false
    watch_list::Vector
    # lowered_status::Bool
    # mode
    function Server(in, out)
        new(in, out, UNINITIALIZED, 0, Dict{Int64,Frame}(), 1, [])
    end
end

seq!(server::Server) = server.last_seq += 1


function Base.write(server::Server, pm::ProtocolMessage)
    payload = JSON.json(pm)
    println(stderr, "[[[ SENT ]]]\n", payload, "\n\n")
    string("Content-Length: $(length(payload))\r\n\r\n", payload)
    write(server.out, payload)
end

# receive a generic message
function Base.read(comm::Server)
    buf = readuntil(comm.in, "\r\n\r\n", keep=true)
    nb = parse(Int64, match(r"Content-Length:\s*([0-9]*)"s, buf)[1])
    payload = String(read(comm.in, nb))
    println(stderr, "[[[ RECEIVED ]]]\n", payload, "\n\n")
    return ProtocolMessage(JSON.parse(payload))
end

# send a response to a request
function respond!(server::Server, request::Request, body::T; success::Bool=true, message::Union{Missing,String}=missing) where T
    # ensure response type matches request type
    @assert request_command(request) == response_command(body)

    # construct and send our response
    write(server, Response{T}(seq=seq!(server), request_seq=request.seq, body=body,
        success=success, message=message, command = string(response_command(body))))
end
export respond!

# send a request
function request!(comm::Server, body::T) where T
    write(comm, Request{T}(seq=seq!(comm), body=body))
end
export request!

# send an event
function signal!(comm::Server, body::T) where T
    write(comm, Event{T}("event", string(event_kind(T)), seq!(comm), body))
end
export signal!


# finish_and_return!() = nothing
# toggle_mode!(server::Server) = server.mode = (server.mode==finish_and_return! ? (server.mode=Compiled()) : (server.mode=finish_and_return!))
# toggle_lowered!(server::Server) = server.lowered_status = !server.lowered_status

# run in a loop
function Base.run(server::Server)
    while isopen(server.in)
        handle!(server, read(server))
    end
end

include("adapterprocess.jl")
include("breakpoints.jl")
include("stepping.jl")
include("introspection.jl")

end  # module Server
