# *** event types ***

@jsonable struct Event{T} <: ProtocolMessage
    seq::Int64
    body::Union{Missing,T} = missing
end

# Event body types provide a custom definition for dispatch on construction from a Dict.
function event_body_type(t::Type{Val{S}}) where S
    @error "Event body type for $(t.parameters[1]) undefined."
end
export event_body_type

# Event body types provide a custom definition for emitting the appropriate `event`
# property.
event_kind(::Type{T}) where T = @error "Event kind for type $(T) undefined."
event_kind(::Type{Event{T}}) where T = event_kind(T)
event_kind(x) = event_kind(typeof(x))
export event_kind

# Provides both explicit and implicit properties necessary for serialization to JSON.
Base.propertynames(x::Event) = (:seq, :type, :event, :body)
function Base.getproperty(x::Event{T}, s::Symbol) where T
    if s === :type
        :event
    elseif s === :event
        event_kind(T)
    else
        getfield(x, s)
    end
end

# hook for constructing an Event from a Dict via `ProtocolMessage(::Dict)`
protocol_message_type(::Type{Val{:event}}) = Event

# construction from a Dict
function Event(d::Dict)
    bodytype = event_body_type(Val{Symbol(d["event"])})
    body = bodytype(get(d, "body", Dict()))
    Event{bodytype}(d["seq"], body)
end


#=
    @event struct Blah
        ...
    end :a=>:b :c=>:d

becomes:

    @jsonable struct BlahEventBody
        ...
    end :a=>:b :c=>:d

    const BlahEvent = Event{BlahEventBody}
    export BlahEvent
    event_body_type(::Type{Val{:blah}}) = BlahEventBody
    event_kind(::Type{BlahEventBody}) = :blah
=#
macro event(structdefn, prs...)
    corename = structdefn.args[2]
    expr = QuoteNode(Symbol(lowercasefirst(string(corename))))
    bodyname = Symbol(string(corename)*"EventBody")
    aliasname = Symbol(string(corename)*"Event")
    structdefn.args[2] = bodyname
    esc(quote
        @exported_jsonable $structdefn $(prs...)

        const $aliasname = Event{$bodyname}
        export $aliasname
        event_body_type(::Type{Val{$expr}}) = $bodyname
        event_kind(::Type{$bodyname}) = $expr
    end)
end


# *** concrete event types ***

@event struct Breakpoint
    reason::String
    breakpoint::Breakpoint
end

@event struct Capabilities
    capabilities::Capabilities
end

@event struct Continued
    threadId::Int64
    allThreadsContinued::Union{Missing,Bool} = missing
end

@event struct Exited
    exitCode::Int64
end

@event struct Initialized end

@event struct LoadedSource
    reason::LoadedReason
    source::Source
end

@event struct Module
    reason::LoadedReason
    mod::Module
end :module => :mod

@event struct Output
    category::Union{Missing,String} = missing
    output::String
    variablesReference::Union{Missing,Int64} = missing
    source::Union{Missing,Source} = missing
    line::Union{Missing,Int64} = missing
    column::Union{Missing,Int64} = missing
    data::Any = missing
end

@event struct Process
    name::String
    systemProcessId::Union{Missing,Int64} = missing
    isLocalProcess::Union{Missing,Bool} = missing
    startMethod::Union{Missing,StartMethod} = missing
    pointerSize::Union{Missing,Int64} = missing
end

@event struct Stopped
    reason::StoppedReason
    description::Union{Missing,String} = missing
    threadId::Union{Missing,Int64} = missing
    preserveFocusHint::Union{Missing,Bool} = missing
    text::Union{Missing,String} = missing
    allThreadsStopped::Union{Missing,Bool} = missing
end

@event struct Terminated
    restart::Any = missing
end

@event struct Thread
    reason::String
    threadId::Int64
end
