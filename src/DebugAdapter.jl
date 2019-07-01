module DebugAdapter

abstract type Event end
abstract type Response end
abstract type Request end
include("types.jl")
include("events.jl")
include("requests.jl")
include("responses.jl")


end