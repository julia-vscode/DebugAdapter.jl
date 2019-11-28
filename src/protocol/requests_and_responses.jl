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
    aliasname = structdefn.args[2] 
    corename = Symbol(string(aliasname)[1:end-7])

    # corename = structdefn.args[2]
    expr = QuoteNode(Symbol(lowercasefirst(string(corename))))
    bodyname = Symbol(string(corename)*"RequestArguments")
    # aliasname = Symbol(string(corename)*"Request")
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
    type::String = "response"
    command::String
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
    alias = structdefn.args[2]
    corename = String(string(alias)[1:end-8])

    # corename = string(structdefn.args[2])
    qsym = QuoteNode(Symbol(lowercasefirst(corename)))
    # alias = Symbol(corename*"Response")
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

@request struct AttachRequest
    __restart::Any = missing
end

@response struct AttachResponse end

@request struct CompletionsRequest
    frameId::Union{Missing,Int64} = missing
    text::String
    column::Int64
    line::Union{Missing,Int64} = missing
end

@response struct CompletionsResponse
    targets::Vector{CompletionItem} = CompletionItem[]
end

@request struct ConfigurationDoneRequest end

@response struct ConfigurationDoneResponse end

@request struct ContinueRequest
    threadId::Int64
end

@response struct ContinueResponse
    allThreadsContinued::Union{Missing,Bool} = missing
end

@request struct DataBreakpointInfoRequest
    variableReference::Union{Missing,Int64} = missing
    name::String
end

@response struct DataBreakpointInfoResponse
    dataId::Union{Missing,String} = missing
    description::String
    accessTypes::Union{Missing,Vector{DataBreakpointAccessType}} = missing
    canPersist::Union{Missing,Bool} = missing
end

@request struct DisassembleRequest
    memoryReference::String
    offset::Union{Missing,Int64} = missing
    instructionOffset::Union{Missing,Int64} = missing
    instructionCount::Int64
    resolveSymbols::Union{Missing,Bool} = missing
end

@response struct DisassembleResponse
    instructions::Vector{DisassembledInstruction} = DisassembledInstruction[]
end

@request struct DisconnectRequest
    restart::Union{Missing,Bool} = missing
    terminateDebuggee::Union{Missing,Bool} = missing
end

@response struct DisconnectResponse end

@request struct EvaluateRequest
    expression::String
    frameId::Union{Missing,Int64} = missing
    context::Union{Missing,String} = missing
    format::Union{Missing,ValueFormat} = missing
end

@response struct EvaluateResponse
    result::String
    type::Union{Missing,String} = missing
    presentationHint::Union{Missing,VariablePresentationHint} = missing
    variablesReference::Int64
    namedVariables::Union{Missing,Int64} = missing
    indexedVariables::Union{Missing,Int64} = missing
    memoryReference::Union{Missing,String} = missing
end

@request struct ExceptionInfoRequest
    threadId::Int64
end

@response struct ExceptionInfoResponse
    exceptionId::String
    description::Union{Missing,String} = missing
    breakMode::ExceptionBreakMode
    details::Union{Missing,ExceptionDetails} = missing
end

@request struct GotoRequest
    threadId::Int64
    targetId::Int64
end

@response struct GotoResponse end

@request struct GotoTargetsRequest
    source::Source
    line::Int64
    column::Union{Missing,Int64} = missing
end

@response struct GotoTargetsResponse
    targets::Vector{GotoTarget} = GotoTarget[]
end

@request struct InitializeRequest
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

@response struct InitializeResponse
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

@request struct LaunchRequest
    noDebug::Union{Missing,Bool} = missing
    __restart::Any = missing
end

@response struct LaunchResponse end

@request struct LoadedSourcesRequest end

@response struct LoadedSourcesResponse
    sources::Vector{Source} = Source[]
end

@request struct ModulesRequest
    startModule::Union{Missing,Int64} = missing
    moduleCount::Union{Missing,Int64} = missing
end

@response struct ModulesResponse
    modules::Vector{Module} = Module[]
    totalModules::Union{Missing,Int64} = missing
end

@request struct NextRequest
    threadId::Int64
end

@response struct NextResponse end

@request struct PauseRequest
    threadId::Int64
end

@response struct PauseResponse end

@request struct ReadMemoryRequest
    memoryReference::String
    offset::Union{Missing,Int64} = missing
    count::Int64
end

@response struct ReadMemoryResponse
    address::String
    unreadableBytes::Union{Missing,Int64} = missing
    data::Union{Missing,String} = missing
end

@request struct RestartRequest end

@response struct RestartResponse end

@request struct RestartFrameRequest
    frameId::Int64
end

@response struct RestartFrameResponse end

@request struct ReverseContinueRequest
    threadId::Int64
end

@response struct ReverseContinueResponse end

@request struct RunInTerminalRequest
    kind::Union{Missing,TerminalKind} = missing
    title::Union{Missing,String} = missing
    cwd::String
    args::Vector{String} = String[]
    env::Union{Missing,Dict{String,Union{Nothing,String}}} = missing
end

@response struct RunInTerminalResponse
    processId::Union{Missing,Int64} = missing
    shellProcessId::Union{Missing,Int64} = missing
end

@request struct ScopesRequest
    frameId::Int64
end

@response struct ScopesResponse
   scopes::Vector{Scope} = Scope[]
end

@request struct SetBreakpointsRequest
    source::Source
    breakpoints::Union{Missing,Vector{SourceBreakpoint}} = missing
    lines::Union{Missing, Vector{Int64}} = missing
    sourceModified::Union{Missing,Bool} = missing
end

@response struct SetBreakpointsResponse
    breakpoints::Vector{Breakpoint} = Breakpoint[]
end

@request struct SetDataBreakpointsRequest
    breakpoints::Vector{DataBreakpoint} = DataBreakpoint[]
end

@response struct SetDataBreakpointsResponse
    breakpoints::Vector{Breakpoint} = Breakpoint[]
end

@request struct SetExceptionBreakpointsRequest
    filters::Vector{String} = String[]
    exceptionOptions::Union{Missing,Vector{ExceptionOptions}} = missing
end

@response struct SetExceptionBreakpointsResponse end

@request struct SetExpressionRequest
    expression::String
    value::String
    frameId::Union{Missing,Int64} = missing
    format::Union{Missing,ValueFormat} = missing
end

@response struct SetExpressionResponse
    value::String
    type::Union{Missing,String} = missing
    presentationHint::Union{Missing,VariablePresentationHint} = missing
    variablesReference::Union{Missing,Int64} = missing
    namedVariables::Union{Missing,Int64} = missing
    indexedVariables::Union{Missing,Int64} = missing
end

@request struct SetFunctionBreakpointsRequest
    breakpoints::Vector{FunctionBreakpoint} = FunctionBreakpoint[]
end

@response struct SetFunctionBreakpointsResponse
    breakpoints::Vector{Breakpoint} = Breakpoint[]
end

@request struct SetVariableRequest
    variablesReference::Int64
    name::String
    value::String
    format::Union{Missing,ValueFormat} = missing
end

@response struct SetVariableResponse
    value::String
    type::Union{Missing,String} = missing
    variablesReference::Union{Missing,Int64} = missing
    namedVariables::Union{Missing,Int64} = missing
    indexedVariables::Union{Missing,Int64} = missing
end

@request struct SourceRequest
    source::Union{Missing,Source} = missing
    sourceReference::Int64
end

@response struct SourceResponse
    content::String
    mimeType::Union{Missing,String} = missing
end

@request struct StackTraceRequest
    threadId::Int64
    startFrame::Union{Missing,Int64} = missing
    levels::Union{Missing,Int64} = missing
    format::Union{Missing,StackFrameFormat} = missing
end

@response struct StackTraceResponse
    stackFrames::Vector{StackFrame} = StackFrame[]
    totalFrames::Union{Missing,Int64} = missing
end

@request struct StepBackRequest
    threadId::Int64
end

@response struct StepBackResponse end

@request struct StepInRequest
    threadId::Int64
    targetId::Union{Missing,Int64} = missing
end

@response struct StepInResponse end

@request struct StepInTargetsRequest
    frameId::Int64
end

@response struct StepInTargetsResponse
    targets::Vector{StepInTarget} = StepInTarget[]
end

@request struct StepOutRequest
    threadId::Int64
end

@response struct StepOutResponse end

@request struct TerminateRequest
    restart::Union{Missing,Bool} = missing
end

@response struct TerminateResponse end

@request struct TerminateThreadsRequest
    threadIds::Union{Missing,Vector{Int64}} = missing
end

@response struct TerminateThreadsResponse end

@request struct ThreadsRequest end

@response struct ThreadsResponse
    threads::Vector{Thread} = Thread[]
end

@request struct VariablesRequest
    variablesReference::Int64
    filter::Union{Missing,VariablesFilter} = missing
    start::Union{Missing,Int64} = missing
    count::Union{Missing,Int64} = missing
    format::Union{Missing,ValueFormat} = missing
end

@response struct VariablesResponse
    variables::Vector{Variable} = Variable[]
end
