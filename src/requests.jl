struct Request{T} <: ProtocolMessage
    seq::Int
    arguments::T
end
export Request

request_arguments_type(t::Type{Val{S}}) where S = @error "Request arguments type $(t.parameters[1]) undefined."

function Request(d::Dict)
    argumentstype = request_arguments_type(Val{Symbol(d["command"])})
    arguments = argumentstype(get(d, "arguments", Dict()))
    Request{argumentstype}(d["seq"], arguments)
end

protocol_message_type(::Type{Val{:request}}) = Request

macro request(structdefn, subst = Dict{Symbol,String}())
    corename = structdefn.args[2]
    argumentsval = Val{Symbol(lowercasefirst(string(corename)))}
    bodyname = Symbol(string(corename)*"RequestArguments")
    aliasname = Symbol(string(corename)*"Request")
    structdefn.args[2] = bodyname
    esc(quote
        @dict_ctor $structdefn $subst
        const $aliasname = Request{$bodyname}
        export $aliasname
        request_arguments_type(::Type{$argumentsval}) = $bodyname
    end)
end

@request struct Attach
    __restart::Union{Nothing,Any}
end

@request struct Completions
    frameId::Union{Nothing,Int}
    text::String
    column::Int
    line::Union{Nothing,Int}
end

@request struct ConfigurationDone end

@request struct Continue
    threadId::Int
end

@request struct DataBreakpointInfo
    variableReference::Union{Nothing,Int}
    name::String
end

@request struct Disassemble
    memoryReference::String
    offset::Union{Nothing,Int}
    instructionOffset::Union{Nothing,Int}
    instructionCount::Int
    resolveSymbols::Union{Nothing,Bool}
end

@request struct Disconnect
    restart::Union{Nothing,Bool}
    terminateDebuggee::Union{Nothing,Bool}
end

@request struct Evaluate
    expression::String
    frameId::Union{Nothing,Int}
    context::Union{Nothing,String}
    format::Union{Nothing,ValueFormat}
end

@request struct ExceptionInfo
    threadId::Int
end

@request struct Goto
    threadId::Int
    targetId::Int
end

@request struct GotoTargets
    source::Source
    line::Int
    column::Union{Nothing,Int}
end

@request struct Initialize
    clientID::Union{Nothing,String}
    clientName::Union{Nothing,String}
    adapterID::String
    locale::Union{Nothing,String}
    linesStartAt1::Union{Nothing,Bool}
    columnsStartAt1::Union{Nothing,Bool}
    pathFormat::Union{Nothing,String}
    supportsVariableType::Union{Nothing,Bool}
    supportsVariablePaging::Union{Nothing,Bool}
    supportsRunInTerminalRequest::Union{Nothing,Bool}
    supportsMemoryReferences::Union{Nothing,Bool}
end

@request struct Launch
    noDebug::Union{Nothing,Bool}
    __restart::Union{Nothing,Any}
end

@request struct LoadedSources end

@request struct Modules
    startModule::Union{Nothing,Int}
    moduleCount::Union{Nothing,Int}
end

@request struct Next
    threadId::Int
end

@request struct Pause
    threadId::Int
end

@request struct ReadMemory
    memoryReference::String
    offset::Union{Nothing,Int}
    count::Int
end

@request struct Restart end

@request struct RestartFrame
    frameId::Int
end

@request struct ReverseContinue
    threadId::Int
end

const TerminalKind = String
const TerminalKinds = ("integrated", "external")

@request struct RunInTerminal
    kind::Union{Nothing,TerminalKind}
    title::Union{Nothing,String}
    cwd::String
    args::Vector{String}
    env::Union{Nothing,Dict{String,Union{Nothing,String}}}
end

@request struct Scopes
    frameId::Int
end

@request struct SetBreakpoints
    source::Source
    breakpoints::Union{Nothing,Vector{SourceBreakpoint}}
    lines::Union{Nothing,Vector{Int}}
    sourceModified::Union{Nothing,Bool}
end

@request struct DataBreakpointsInfo
    variablesReference::Union{Nothing,Int}
    name::String
end

@request struct SetDataBreakpoints
    breakpoints::Vector{DataBreakpoint}
end

@request struct SetExceptionBreakpoints
    filters::Vector{String}
    exceptionOptions::Union{Nothing,Vector{ExceptionOptions}}
end

@request struct SetExpression
    expression::String
    value::String
    frameId::Union{Nothing,Int}
    format::Union{Nothing,ValueFormat}
end

@request struct SetFunctionBreakpoints
    breakpoints::Vector{FunctionBreakpoint}
end

@request struct SetVariable
    variablesReference::Int
    name::String
    value::String
    format::Union{Nothing,ValueFormat}
end

@request struct Source
    source::Union{Nothing,Source}
    sourceReference::Int
end

@request struct StackTrace
    threadId::Int
    startFrame::Union{Nothing,Int}
    levels::Union{Nothing,Int}
    format::Union{Nothing,StackFrameFormat}
end

@request struct StepBack
    threadId::Int
end

@request struct StepIn
    threadId::Int
    targetId::Union{Nothing,Int}
end

@request struct StepInTargets
    frameId::Int
end

@request struct StepOut
    threadId::Int
end

@request struct Terminate
    restart::Union{Nothing,Bool}
end

@request struct TerminateThreads
    threadIds::Union{Nothing,Vector{Int}}
end

@request struct Threads end

@request struct Variables
    variablesReference::Int
    filter::Union{Nothing,String}
    start::Union{Nothing,Int}
    count::Union{Nothing,Int}
    format::Union{Nothing,ValueFormat}
end
