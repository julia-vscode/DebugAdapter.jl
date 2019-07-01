struct ErrorResponse <: Response
    error::Union{Nothing,Message}
end

struct RunInTerminalResponse <: Response
    processId::Union{Nothing,Int}
    shellProcessId::Union{Nothing,Int}
end

struct InitializeResponse <: Response end
struct ConfigurationDoneResponse <: Response end
struct LaunchResponse <: Response end
struct AttachResponse <: Response end
struct RestartResponse <: Response end
struct DisconnectResponse <: Response end
struct TerminateResponse <: Response end

struct SetBreakpointsResponse <: Response
    breakpoints::Vector{Breakpoint}
end

struct SetFunctionBreakpointsResponse <: Response
    breakpoints::Vector{Breakpoint}
end

struct SetExceptionBreakpointsResponse <: Response
    filters::Vector{String}
    exceptionOptions::Union{Nothing,Vector{ExceptionOptions}}
end

struct DataBreakpointInfoResponse <: Response
    data::Union{Nothing,String}
    description::String
    accessTypes::Union{Nothing,Vector{DataBreakpointAccessType}}
    canPersist::Union{Nothing,Bool}
end

struct SetDataBreakpointsResponse <: Response
    breakpoints::Vector{Breakpoint}    
end

struct ContinueResponse <: Response
    allThreadsContinued::Union{Nothing,Bool}
end

struct NextResponse <: Response end
struct StepInResponse <: Response end
struct StepOutResponse <: Response end
struct StepBackResponse <: Response end
struct ReverseContinueResponse <: Response end
struct RestartFrameResponseResponse <: Response end
struct GotoResponse <: Response end
struct PauseResponse <: Response end

struct StackTraceResponse <: Response
    stackFrames::Vector{StackFrame}
    totalFrames::Union{Nothing,Int}
end

struct ScopesResponse <: Response
    frameId::Int
end

struct VariablesResponse <: Response
    variables::Vector{Variable}
end

struct SetVariableResponse <: Response
    value::String
    type::Union{Nothing,String}
    variablesReference::Union{Nothing,Int}
    namedVariables::Union{Nothing,Int}
    indexedVariables::Union{Nothing,Int}
end

struct SourceResponse <: Response
    content::String
    mimeType::Union{Nothing,String}
end

struct ThreadsResponse <: Response
    threads::Vector{Thread}
end

struct TerminateThreadsResponse <: Response end

struct ModulesResponse <: Response
    startModule::Union{Nothing,Int}
    moduleCount::Union{Nothing,Int}
end

struct LoadedSourcesResponse <: Response
    sources::Vector{Source}
end

struct EvaluateResponse <: Response
    result::String
    type::Union{Nothing,String}
    presentationHint::Union{Nothing,VariablePresentationHint}
    variablesReference::Int
    namedVariables::Union{Nothing,Int}
    indexedVariables::Union{Nothing,Int}
    memoryReference::Union{Nothing,String}
end

struct SetExpressionResponse <: Response
    value::String
    type::Union{Nothing,String}
    presentationHint::Union{Nothing,VariablePresentationHint}
    variablesReference::Int
    namedVariables::Union{Nothing,Int}
    indexedVariables::Union{Nothing,Int}
end

struct StepInTargetsResponse <: Response
    targets::Vector{StepInTarget}
end

struct GotoTargetsResponse <: Response
    targets::Vector{GotoTarget}
end

struct CompletionsResponse <: Response
    targets::Vector{CompletionItem}
end

struct ExceptionInfoResponse <: Response
    exceptionId::String
    description::Union{Nothing,String}
    breakMode::ExceptionBreakMode
    details::Union{Nothing,ExceptionDetails}
end

struct ReadMemoryResponse <: Response
    address::String
    unreadableBytes::Union{Nothing,Int}
    data::Union{Nothing,String}
end

struct DisassembleResponse <: Response
    instructions::Union{Nothing,DisassembledInstruction}
end
