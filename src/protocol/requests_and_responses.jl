# *** request types ***

@jsonable struct Request{T} <: ProtocolMessage
    seq::Int64
    arguments::Union{Missing,T} = missing
end

# Request arguments types provide a custom definition for dispatch on construction from a
# Dict.
function request_arguments_type(t::Type{Val{S}}) where S
    @error "Request arguments type for $(t.parameters[1]) undefined."
end
export request_arguments_type

# Request arguments types provide a custom definition for emitting the appropriate `command`
# property.
request_command(::Type{T}) where T = @error "Request command for type $(T) undefined."
request_command(::Type{Request{T}}) where T = request_command(T)
request_command(x) = request_command(typeof(x))
export request_command

# Provides both explicit and implicit properties necessary for serialization to JSON.
Base.propertynames(x::Request) = (:seq, :type, :command, :arguments)
function Base.getproperty(x::Request{T}, s::Symbol) where T
    if s === :type
        :request
    elseif s === :command
        request_command(T)
    else
        getfield(x, s)
    end
end

# hook for constructing a Request from a Dict via `ProtocolMessage(::Dict)`
protocol_message_type(::Type{Val{:request}}) = Request

# construction from a Dict
function Request(d::Dict)
    argumentstype = request_arguments_type(Val{Symbol(d["command"])})
    arguments = argumentstype(get(d, "arguments", Dict()))
    Request{argumentstype}(d["seq"], arguments)
end


#=
    @request struct Blah
        ...
    end :a=>:b :c=>:d

becomes:

    @jsonable struct BlahRequestArguments
        ...
    end :a=>:b :c=>:d

    const BlahRequest = Request{BlahRequestArguments}
    export BlahRequest
    request_arguments_type(::Type{Val{:blah}}) = BlahRequestArguments
    request_command(::Type{BlahRequestArguments}) = :blah
=#
macro request(structdefn, prs...)
    corename = structdefn.args[2]
    expr = QuoteNode(Symbol(lowercasefirst(string(corename))))
    bodyname = Symbol(string(corename)*"RequestArguments")
    aliasname = Symbol(string(corename)*"Request")
    structdefn.args[2] = bodyname
    esc(quote
        @jsonable $structdefn $(prs...)

        const $aliasname = Request{$bodyname}
        export $aliasname
        request_arguments_type(::Type{Val{$expr}}) = $bodyname
        request_command(::Type{$bodyname}) = $expr
    end)
end


# *** response types ***

@jsonable struct Response{T} <: ProtocolMessage
    seq::Int64
    request_seq::Int64
    success::Bool = true
    message::Union{Missing,String} = missing
    body::Union{Missing,T} = missing
end
export Response

# Response body types provide a custom definition for dispatch on construction from a Dict.
function response_body_type(t::Type{Val{S}}) where S
    @error "Response body type for $(t.parameters[1]) undefined."
end
export response_body_type

# Response body types provide a custom definition for emitting the appropriate `command`
# property.
response_command(::Type{T}) where T = @error "Response command for type $(T) undefined."
response_command(::Type{Response{T}}) where T = response_command(T)
response_command(x) = response_command(typeof(x))
export response_command

# Provides both explicit and implicit properties necessary for serialization to JSON
function Base.propertynames(x::Response)
    (:seq, :type, :request_seq, :success, :command, :message, :body)
end

function Base.getproperty(x::Response{T}, s::Symbol) where T
    if s === :type
        :response
    elseif s === :command
        response_command(T)
    else
        getfield(x, s)
    end
end

# hook for constructing a Response from a Dict via `ProtocolMessage(::Dict)`
protocol_message_type(::Type{Val{:response}}) = Response

# construction from a Dict
function Response(d::Dict)
    success = d["success"]
    msg = get(d, "message", missing)
    bodytype = response_body_type(Val{Symbol(d["command"])})
    body = bodytype(get(d, "body", Dict()))
    Response{bodytype}(d["seq"], d["request_seq"], success, msg, body)
end

#=
    @response struct Blah
        ...
    end :a=>:b :c=>:d

becomes:

    @jsonable struct BlahResponseBody
        ...
        error::Union{Missing,Message} = missing
    end :a=>:b :c=>:d

    const BlahResponse = Response{BlahResponseBody}
    export BlahResponse
    response_body_type(::Type{Val{:blah}}) = BlahResponseBody
    response_command(::Type{BlahResponseBody}) = :blah

Note that an `error` field is injected so that all response body types automatically support
# the `ErrorResponse` interface.
=#
macro response(structdefn, prs...)
    corename = string(structdefn.args[2])
    qsym = QuoteNode(Symbol(lowercasefirst(corename)))
    alias = Symbol(corename*"Response")
    bodyname = Symbol(corename*"ResponseBody")
    structdefn.args[2] = bodyname
    push!(structdefn.args[3].args, :(error::Union{Missing,Message} = missing))
    esc(quote
        @jsonable $structdefn $(prs...)

        const $alias = Response{$bodyname}
        export $alias
        response_body_type(::Type{Val{$qsym}}) = $bodyname
        response_command(::Type{$bodyname}) = $qsym
    end)
end


# *** concrete request and response types ***

@request struct Attach
    __restart::Any = missing
end

@response struct Attach end

@request struct Completions
    frameId::Union{Missing,Int64} = missing
    text::String
    column::Int64
    line::Union{Missing,Int64} = missing
end

@response struct Completions
    targets::Vector{CompletionItem} = CompletionItem[]
end

@request struct ConfigurationDone end

@response struct ConfigurationDone end

@request struct Continue
    threadId::Int64
end

@response struct Continue
    allThreadsContinued::Union{Missing,Bool} = missing
end

@request struct DataBreakpointInfo
    variableReference::Union{Missing,Int64} = missing
    name::String
end

@response struct DataBreakpointInfo
    dataId::Union{Missing,String} = missing
    description::String
    accessTypes::Union{Missing,Vector{DataBreakpointAccessType}} = missing
    canPersist::Union{Missing,Bool} = missing
end

@request struct Disassemble
    memoryReference::String
    offset::Union{Missing,Int64} = missing
    instructionOffset::Union{Missing,Int64} = missing
    instructionCount::Int64
    resolveSymbols::Union{Missing,Bool} = missing
end

@response struct Disassemble
    instructions::Vector{DisassembledInstruction} = DisassembledInstruction[]
end

@request struct Disconnect
    restart::Union{Missing,Bool} = missing
    terminateDebuggee::Union{Missing,Bool} = missing
end

@response struct Disconnect end

@request struct Evaluate
    expression::String
    frameId::Union{Missing,Int64} = missing
    context::Union{Missing,String} = missing
    format::Union{Missing,ValueFormat} = missing
end

@response struct Evaluate
    result::String
    type::Union{Missing,String} = missing
    presentationHint::Union{Missing,VariablePresentationHint} = missing
    variablesReference::Int64
    namedVariables::Union{Missing,Int64} = missing
    indexedVariables::Union{Missing,Int64} = missing
    memoryReference::Union{Missing,String} = missing
end

@request struct ExceptionInfo
    threadId::Int64
end

@response struct ExceptionInfo
    exceptionId::String
    description::Union{Missing,String} = missing
    breakMode::ExceptionBreakMode
    details::Union{Missing,ExceptionDetails} = missing
end

@request struct Goto
    threadId::Int64
    targetId::Int64
end

@response struct Goto end

@request struct GotoTargets
    source::Source
    line::Int64
    column::Union{Missing,Int64} = missing
end

@response struct GotoTargets
    targets::Vector{GotoTarget} = GotoTarget[]
end

@request struct Initialize
    clientID::Union{Missing,String} = missing
    clientName::Union{Missing,String} = missing
    adapterID::String
    locale::Union{Missing,String} = missing
    linesStartAt1::Union{Missing,Bool} = missing
    columnsStartAt1::Union{Missing,Bool} = missing
    pathFormat::Union{Missing,PathFormat} = missing
    supportsVariableType::Union{Missing,Bool} = missing
    supportsVariablePaging::Union{Missing,Bool} = missing
    supportsRunInTerminalRequest::Union{Missing,Bool} = missing
    supportsMemoryReferences::Union{Missing,Bool} = missing
end

@response struct Initialize
    supportsConfigurationDoneRequest::Union{Missing,Bool} = missing
    supportsFunctionBreakpoints::Union{Missing,Bool} = missing
    supportsConditionalBreakpoints::Union{Missing,Bool} = missing
    supportsHitConditionalBreakpoints::Union{Missing,Bool} = missing
    supportsEvaluateForHovers::Union{Missing,Bool} = missing
    exceptionBreakpointFilters::Union{Missing,Vector{ExceptionBreakpointsFilter}} = missing
    supportsStepBack::Union{Missing,Bool} = missing
    supportsSetVariable::Union{Missing,Bool} = missing
    supportsRestartFrame::Union{Missing,Bool} = missing
    supportsGotoTargetsRequest::Union{Missing,Bool} = missing
    supportsStepInTargetsRequest::Union{Missing,Bool} = missing
    supportsCompletionsRequest::Union{Missing,Bool} = missing
    supportsModulesRequest::Union{Missing,Bool} = missing
    additionalModuleColumns::Union{Missing,Vector{ColumnDescriptor}} = missing
    supportedChecksumAlgorithms::Union{Missing,Vector{ChecksumAlgorithm}} = missing
    supportsRestartRequest::Union{Missing,Bool} = missing
    supportsExceptionOptions::Union{Missing,Bool} = missing
    supportsValueFormattingOptions::Union{Missing,Bool} = missing
    supportsExceptionInfoRequest::Union{Missing,Bool} = missing
    supportTerminateDebuggee::Union{Missing,Bool} = missing
    supportsDelayedStackTraceLoading::Union{Missing,Bool} = missing
    supportsLoadedSourcesRequest::Union{Missing,Bool} = missing
    supportsLogPoints::Union{Missing,Bool} = missing
    supportsTerminateThreadsRequest::Union{Missing,Bool} = missing
    supportsSetExpression::Union{Missing,Bool} = missing
    supportsTerminateRequest::Union{Missing,Bool} = missing
    supportsDataBreakpoints::Union{Missing,Bool} = missing
    supportsReadMemoryRequest::Union{Missing,Bool} = missing
    supportsDisassembleRequest::Union{Missing,Bool} = missing
end
const Capabilities = InitializeResponseBody
export Capabilities

@request struct Launch
    noDebug::Union{Missing,Bool} = missing
    __restart::Any = missing
end

@response struct Launch end

@request struct LoadedSources end

@response struct LoadedSources
    sources::Vector{Source} = Sources[]
end

@request struct Modules
    startModule::Union{Missing,Int64} = missing
    moduleCount::Union{Missing,Int64} = missing
end

@response struct Modules
    modules::Vector{Module} = Module[]
    totalModules::Union{Missing,Int64} = missing
end

@request struct Next
    threadId::Int64
end

@response struct Next end

@request struct Pause
    threadId::Int64
end

@response struct Pause end

@request struct ReadMemory
    memoryReference::String
    offset::Union{Missing,Int64} = missing
    count::Int64
end

@response struct ReadMemory
    address::String
    unreadableBytes::Union{Missing,Int64} = missing
    data::Union{Missing,String} = missing
end

@request struct Restart end

@response struct Restart end

@request struct RestartFrame
    frameId::Int64
end

@response struct RestartFrame end

@request struct ReverseContinue
    threadId::Int64
end

@response struct ReverseContinue end

@request struct RunInTerminal
    kind::Union{Missing,TerminalKind} = missing
    title::Union{Missing,String} = missing
    cwd::String
    args::Vector{String} = String[]
    env::Union{Missing,Dict{String,Union{Nothing,String}}} = missing
end

@response struct RunInTerminal
    processId::Union{Missing,Int64} = missing
    shellProcessId::Union{Missing,Int64} = missing
end

@request struct Scopes
    frameId::Int64
end

@response struct Scopes
   scopes::Vector{Scope} = Scope[]
end

@request struct SetBreakpoints
    source::Source
    breakpoints::Union{Missing,Vector{SourceBreakpoint}} = missing
    lines::Union{Missing, Vector{Int64}} = missing
    sourceModified::Union{Missing,Bool} = missing
end

@response struct SetBreakpoints
    breakpoints::Vector{Breakpoint} = Breakpoint[]
end

@request struct SetDataBreakpoints
    breakpoints::Vector{DataBreakpoint} = DataBreakpoint[]
end

@response struct SetDataBreakpoints
    breakpoints::Vector{Breakpoint} = Breakpoint[]
end

@request struct SetExceptionBreakpoints
    filters::Vector{String} = String[]
    exceptionOptions::Union{Missing,Vector{ExceptionOptions}} = missing
end

@response struct SetExceptionBreakpoints end

@request struct SetExpression
    expression::String
    value::String
    frameId::Union{Missing,Int64} = missing
    format::Union{Missing,ValueFormat} = missing
end

@response struct SetExpression
    value::String
    type::Union{Missing,String} = missing
    presentationHint::Union{Missing,VariablePresentationHint} = missing
    variablesReference::Union{Missing,Int64} = missing
    namedVariables::Union{Missing,Int64} = missing
    indexedVariables::Union{Missing,Int64} = missing
end

@request struct SetFunctionBreakpoints
    breakpoints::Vector{FunctionBreakpoint} = FunctionBreakpoint[]
end

@response struct SetFunctionBreakpoints
    breakpoints::Vector{Breakpoint} = Breakpoint[]
end

@request struct SetVariable
    variablesReference::Int64
    name::String
    value::String
    format::Union{Missing,ValueFormat} = missing
end

@response struct SetVariable
    value::String
    type::Union{Missing,String} = missing
    variablesReference::Union{Missing,Int64} = missing
    namedVariables::Union{Missing,Int64} = missing
    indexedVariables::Union{Missing,Int64} = missing
end

@request struct Source
    source::Union{Missing,Source} = missing
    sourceReference::Int64
end

@response struct Source
    content::String
    mimeType::Union{Missing,String} = missing
end

@request struct StackTrace
    threadId::Int64
    startFrame::Union{Missing,Int64} = missing
    levels::Union{Missing,Int64} = missing
    format::Union{Missing,StackFrameFormat} = missing
end

@response struct StackTrace
    stackFrames::Vector{StackFrame} = StackFrame[]
    totalFrames::Union{Missing,Int64} = missing
end

@request struct StepBack
    threadId::Int64
end

@response struct StepBack end

@request struct StepIn
    threadId::Int64
    targetId::Union{Missing,Int64} = missing
end

@response struct StepIn end

@request struct StepInTargets
    frameId::Int64
end

@response struct StepInTargets
    targets::Vector{StepInTarget} = StepInTarget[]
end

@request struct StepOut
    threadId::Int64
end

@response struct StepOut end

@request struct Terminate
    restart::Union{Missing,Bool} = missing
end

@response struct Terminate end

@request struct TerminateThreads
    threadIds::Union{Missing,Vector{Int64}} = missing
end

@response struct TerminateThreads end

@request struct Threads end

@response struct Threads
    threads::Vector{Thread} = Thread[]
end

@request struct Variables
    variablesReference::Int64
    filter::Union{Missing,VariablesFilter} = missing
    start::Union{Missing,Int64} = missing
    count::Union{Missing,Int64} = missing
    format::Union{Missing,ValueFormat} = missing
end

@response struct Variables
    variables::Vector{Variable} = Variable[]
end
