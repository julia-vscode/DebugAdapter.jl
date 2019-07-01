struct InitializedEvent <: Event end

struct StoppedEvent <: Event
    reason::String
    description::Union{Nothing,String}
    threadId::Union{Nothing,Int}
    preserveFocusHint::Union{Nothing,Bool}
    text::Union{Nothing,String}
    allThreadsStopped::Union{Nothing,Bool}
end

struct ContinuedEvent <: Event
    threadId::Int
    allThreadsContinued::Union{Nothing,Bool}
end

struct ExitedEvent <: Event
    exitCode::Int    
end

struct TerminatedEvent <: Event
    restart::Union{Nothing,Any}
end

struct ThreadEvent <: Event
    reason::String
    threadId::Int
end

struct OutputEvent <: Event
    category::Union{Nothing,String}
    output::String
    variablesReference::Union{Nothing,Int}
    source::Union{Nothing,Source}
    line::Union{Nothing,Int}
    column::Union{Nothing,Int}
    data::Union{Nothing,Any}
end

struct BreakpointEvent <: Event
    reason::String
    breakpont::Breakpoint
end

struct ModuleEvent <: Event
    reason::String
    mod::Module
end

struct LoadedSourceEvent <: Event
    reason::String
    source::Source
end

struct ProcessEvent <: Event
    name::String
    systemProcessId::Union{Nothing,Int}    
    isLocalProcess::Union{Nothing,Bool}
    startMethod::Union{Nothing,String}
    pointerSize::Union{Nothing,Int}
end

struct CapabilitiesEvent <: Event
    capabilities::Capabilities
end
