# implementation of the server side of the DAP using JuliaInterpreter
module Servers

using ..DebugAdapter
using ..DebugAdapter.Protocol

import SHA, MD5
using JuliaInterpreter

@enum STATE begin
    UNINITIALIZED
    INITIALIZED
    CONFIGURED
end

Base.@kwdef mutable struct ServerState
    state::STATE = UNINITIALIZED
    frames::Dict{Int64,Frame} = Dict{Int64,Frame}()
    level::Int64 = 1
    broke_on_error:Bool = false
    watch_list::Vector = []
    lowered_status::Bool = false
    mode = finish_and_return!
end
const Server = Comm{ServerState}

toggle_mode!(server::Server) = server.state.mode = (server.state.mode==finish_and_return! ? (server.state.mode=Compiled()) : (server.state.mode=finish_and_return!))
toggle_lowered!(server::Server) = server.state.lowered_status = !server.state.lowered_status

# run in a loop
function run!(server::Server)
    while isopen(server.in)
        handle!(server, read(server))
    end
end

include("adapterprocess.jl")
include("breakpoints.jl")
include("stepping.jl")
include("introspection.jl")

end  # module Server
