module DebugAdapter

import JSON

abstract type ProtocolMessage end
export ProtocolMessage

# subtypes of `ProtocolMessage` provide a custom definition for dispact on construction from a Dict.
protocol_message_type(t::Type{Val{S}}) where S = @error "Protocol message type $(t.parameters[1]) undefined."

# the top-level constructor for serialization from a Dict.
ProtocolMessage(d::Dict) = protocol_message_type(Val{Symbol(d["type"])})(d)

# Converts/filters an associative container to a Dict{Symbol} that can be splatted into a
# keyword-based function. Symbol remappings may be provided which specify additional
# dictionary keys to be used to provide a value for a specified argument name. Note that
# where the dictionary contains multiple keys that map to a single argument name, the last
# relevant key processed provides the value. The order of key processing is:
#  1. the order in which the iterator over the associative container provides pairs;
#  2. left-to-right order of the additional remappings.
function kwargs(assoc, argnames, remaps...)
    d = Dict(Symbol(k)=>v for (k,v) in assoc if Symbol(k) ∈ argnames)
    for (key, argname) in remaps
        k = convert(eltype(assoc), key)
        if haskey(assoc, k)
            d[argname] = assoc[k]
        end
    end
    d
end

# Applies remappings to the given symbol
function kwsubst(s::Symbol, remaps::Pair{Symbol,Symbol}...)
    f = s
    for (prop, field) in remaps
        if s == prop
            f = field
        end
    end
    f
end

# Returns an instance of `JSON.Writer.CompositeTypeWrapper` which will emit only the
# properties whose values satisfy !ismissing. If all properties are missing, returns `missing`.
function json_lower_omit_missings(x)
    syms = filter(k->!ismissing(getproperty(x,k)), propertynames(x))
    isempty(syms) ? missing : JSON.Writer.CompositeTypeWrapper(x, syms)
end

#=
Defines a composite data type, a keyword-based constructor, using `Base.@kwdef`, and a
constructor from a Dict---which itself uses the keyword-based constructor---along with a
custom definition of `JSON.lower` which omits emitting key-value pairs for properties whose
value is `missing`. Note that a value of `nothing` will result in the explicit emission of a
null value.

If additional property-to-field mappings are provided, it also defines appropriate custom
methods for `propertynames` and `getproperty`.

_E.g._:

    @dictable struct Blah{X, Y} <: Z
        ...
    end :a=>:b :p=>:q

becomes:

    Base.@kwdef struct Blah{X, Y} <: Z
        ...
    end

    function Blah{X, Y}(d::Dict) where {X, Y}
        Blah{X, Y}(;kwargs(d, fieldnames(Blah), :a=>:b, :p=>:q)...)
    end

    JSON.lower(x::Blah) = json_lower_omit_missings(x)

    Base.propertynames(x::Blah) = map(n->kwsubst(n, :a=>:b, :p=>:q), fieldnames(Blah))
    Base.getproperty(x::Blah, s::Symbol) = getfield(x, kwsubst(s, :a=>:b, :p=>:q))
=#
macro dictable(structdefn, prs...)
    structname = structdefn.args[2]
    if structname isa Expr && structname.head == :<:
        structname = structname.args[1]
    end
    barename = structname isa Expr ? structname.args[1] : structname
    kwargexpr = :(kwargs(d, fieldnames($barename)))
    append!(kwargexpr.args, prs)
    ctor = :(function $structname(d::Dict)
                $structname(;$kwargexpr...)
             end)
    if structname isa Expr
        ctor.args[1] = Expr(:where, ctor.args[1], structname.args[2:end]...)
    end
    ex = quote
        Base.@kwdef $structdefn
        $ctor
        JSON.lower(x::$barename) = json_lower_omit_missings(x)
    end
    if length(prs) > 0
        push!(ex.args, :(Base.propertynames(x::$barename) = map(n->kwsubst(n, $(prs...)), fieldnames($barename))))
        push!(ex.args, :(Base.getproperty(x::$barename, s::Symbol) = getfield(x, kwsubst(s, $(prs...)))))
    end
    esc(ex)
end

mutable struct DebugAdapterServer
    pipe_lin
    pipe_out
end

include("types.jl")
include("events.jl")
include("requests_and_responses.jl")
include("comm.jl")
include("server.jl")
include("responses.jl")
include("handlers/adapterprocess.jl")
include("handlers/breakpoints.jl")
include("handlers/stepping.jl")

function send(response, server::DebugAdapterServer)
end

end  # module DebugAdapter
