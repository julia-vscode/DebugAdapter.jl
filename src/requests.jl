struct RunInTerminalRequestArguments <: Request
    kind::Union{Nothing,String}
    title::Union{Nothing,String}
    cwd::String
    args::Vector{String}
    env::Union{Nothing,Dict{String,Union{Nothing,String}}}
end

struct InitializeRequestArguments <: Request
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

struct ConfigurationDoneArguments <: Request end

struct LaunchRequestArguments <: Request
    noDebug::Union{Nothing,Bool}
    __restart::Any
end

struct AttachRequestArguments <: Request
    __restart::Any
end

struct RestartRequestArguments <: Request end

struct DisconnectRequestArguments <: Request
    restart::Union{Nothing,Bool}
    terminateDebuggee::Union{Nothing,Bool}
end

struct TerminateRequestArguments <: Request
    restart::Union{Nothing,Bool}
end

struct SetBreakpointsArguments <: Request
    source::Source
    breakpoints::Union{Nothing,Vector{SourceBreakpoint}}
    lines::Union{Nothing,Vector{Int}}
    sourceModified::Union{Nothing,Bool}
end

struct SetFunctionBreakpointsArguments <: Request
    breakpoints::Vector{FunctionBreakpoint}
end

struct SetExceptionBreakpointsArguments <: Request
    filters::Vector{String}
    exceptionOptions::Union{Nothing,Vector{ExceptionOptions}}
end

struct DataBreakpointInfoArguments <: Request
    variableReference::Union{Nothing,Int}
    name::String
end

struct SetDataBreakpointsArguments <: Request
    breakpoints::Vector{DataBreakpoint}    
end

struct ContinueArguments <: Request
    threadId::Int    
end

struct NextArguments <: Request
    threadId::Int    
end

struct StepInArguments <: Request
    threadId::Int
    targetId::Union{Nothing,Int}
end

struct StepOutArguments <: Request
    threadId::Int    
end

struct StepBackArguments <: Request
    threadId::Int    
end

struct ReverseContinueArguments <: Request
    threadId::Int    
end

struct RestartFrameArguments <: Request
    frameId::Int    
end

struct GotoArguments <: Request
    threadId::Int
    targetId::Int
end

struct PauseArguments <: Request
    threadId::Int
end

struct StackTraceArguments <: Request
    threadId::Int
    startFrame::Union{Nothing,Int}
    levels::Union{Nothing,Int}
    format::Union{Nothing,StackFrameFormat}
end

struct ScopesArguments <: Request
    frameId::Int
end

struct VariablesArguments <: Request
    variablesReference::Int
    filter::Union{Nothing,String}
    start::Union{Nothing,Int}
    count::Union{Nothing,Int}
    format::Union{Nothing,ValueFormat}
end

struct SetVariableArguments <: Request
    variablesReference::Int
    name::String
    value::String
    format::Union{Nothing,ValueFormat}
end

struct SourceArguments <: Request
    source::Union{Nothing,Source}
    sourceReference::Int
end

struct TerminateThreadsArguments <: Request
    threadIds::Union{Nothing,Vector{Int}}
end

struct ModulesArguments <: Request
    startModule::Union{Nothing,Int}
    moduleCount::Union{Nothing,Int}
end

struct LoadedSourcesArguments <: Request end

struct EvaluateArguments <: Request
    expression::String
    frameId::Union{Nothing,Int}
    context::Union{Nothing,String}
    format::Union{Nothing,ValueFormat}
end

struct SetExpressionArguments <: Request
    expression::String
    value::String
    frameId::Union{Nothing,Int}
    format::Union{Nothing,ValueFormat}
end

struct StepInTargetsArguments <: Request
    frameId::Int
end

struct GotoTargetsArguments <: Request
    source::Source
    line::Int
    column::Union{Nothing,Int}
end

struct CompletionsArguments <: Request
    frameId::Union{Nothing,Int}
    text::String
    column::Int
    line::Union{Nothing,Int}
end

struct ExceptionInfoArguments <: Request
    threadId::Int    
end

struct ReadMemoryArguments <: Request
    memoryReference::String
    offset::Union{Nothing,Int}
    count::Int
end

struct DisassembleArguments <: Request
    memoryReference::String
    offset::Union{Nothing,Int}
    instructionOffset::Union{Nothing,Int}
    instructionCount::Int
    resolveSymbols::Union{Nothing,Bool}
end

function request_arg_parse(r::Request)
    if r.command == "runInTerminal"
        RunInTerminalRequestArguments(r.arguments)
    elseif r.command == "initialize"
        InitializeRequestArguments(r.arguments)
    elseif r.command == "configurationDone"
        ConfigurationDoneArguments(r.arguments)
    elseif r.command == "launch"
        LaunchRequestArguments(r.arguments)
    elseif r.command == "attach"
        AttachRequestArguments(r.arguments)
    elseif r.command == "restart"
        RestartRequestArguments(r.arguments)
    elseif r.command == "disconnect"
        DisconnectRequestArguments(r.arguments)
    elseif r.command == "terminate"
        TerminateRequestArguments(r.arguments)
    elseif r.command == "setBreakpoints"
        SetBreakpointsArguments(r.arguments)
    elseif r.command == "setFunctionBreakpoints"
        SetFunctionBreakpointsArguments(r.arguments)
    elseif r.command == "setExceptionBreakpoints"
        SetBreakpointsArguments(r.arguments)
    elseif r.command == "dataBreakpointInfo"
        DataBreakpointInfoArguments(r.arguments)
    elseif r.command == "setDataBreakpoints"
        SetDataBreakpointsArguments(r.arguments)
    elseif r.command == "continue"
        ContinueArguments(r.arguments)
    elseif r.command == "next"
        NextArguments(r.arguments)
    elseif r.command == "stepIn"
        StepInArguments(r.arguments)
    elseif r.command == "stepOut"
        StepOutArguments(r.arguments)
    elseif r.command == "stepBack"
        StepBackArguments(r.arguments)
    elseif r.command == "reverseContinue"
        ReverseContinueArguments(r.arguments)
    elseif r.command == "restartFrame"
        RestartFrameArguments(r.arguments)
    elseif r.command == "goto"
        GotoArguments(r.arguments)
    elseif r.command == "pause"
        PauseArguments(r.arguments)
    elseif r.command == "stackTrace"
        StackTraceArguments(r.arguments)
    elseif r.command == "scopes"
        ScopesArguments(r.arguments)
    elseif r.command == "variables"
        VariablesArguments(r.arguments)
    elseif r.command == "setVariable"
        SetVariableArguments(r.arguments)
    elseif r.command == "source"
        SourceArguments(r.arguments)
    elseif r.command == "threads"
        r.arguments
    elseif r.command == "terminateThreads"
        TerminateThreadsArguments(r.arguments)
    elseif r.command == "modules"
        ModulesArguments(r.arguments)
    elseif r.command == "loadedSources"
        LoadedSourcesArguments(r.arguments)
    elseif r.command == "evaluate"
        EvaluateArguments(r.arguments)
    elseif r.command == "setExpression"
        SetExpressionArguments(r.arguments)
    elseif r.command == "setpInTargets"
        StepInTargetsArguments(r.arguments)
    elseif r.command == "gotoTargets"
        GotoTargetsArguments(r.arguments)
    elseif r.command == "completions"
        CompletionsArguments(r.arguments)
    elseif r.command == "exceptionInfo"
        ExceptionInfoArguments(r.arguments)
    elseif r.command == "readMemory"
        ReadMemoryArguments(r.arguments)
    elseif r.command == "disassemble"
        DisassembleArguments(r.arguments)
    end
end



