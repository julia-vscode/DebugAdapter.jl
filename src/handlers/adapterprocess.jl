function handle(r::Request{InitializeRequestArguments}, server::DebugAdapterServer)
    capabilities = Capabilities(
        false,# supportsConfigurationDoneRequest::Union{Nothing,Bool}
        false,# supportsFunctionBreakpoints::Union{Nothing,Bool}
        false,# supportsConditionalBreakpoints::Union{Nothing,Bool}
        false,# supportsHitConditionalBreakpoints::Union{Nothing,Bool}
        false,# supportsEvaluateForHovers::Union{Nothing,Bool}
        [],# exceptionBreakpointFilters::Vector{ExceptionBreakpointsFilter}
        false,# supportsStepBack::Union{Nothing,Bool}
        false,# supportsSetVariable::Union{Nothing,Bool}
        false,# supportsRestartFrame::Union{Nothing,Bool}
        false,# supportsGotoTargetsRequest::Union{Nothing,Bool}
        false,# supportsStepInTargetsRequest::Union{Nothing,Bool}
        false,# supportsCompletionsRequest::Union{Nothing,Bool}
        false,# supportsModulesRequest::Union{Nothing,Bool}
        [],# additionalModuleColumns::Vector{ColumnDescriptor}
        [],# supportedChecksumAlgorithms::Vector{ChecksumAlgorithm}
        false,# supportsRestartRequest::Union{Nothing,Bool}
        false,# supportsExceptionOptions::Union{Nothing,Bool}
        false,# supportsValueFormattingOptions::Union{Nothing,Bool}
        false,# supportsExceptionInfoRequest::Union{Nothing,Bool}
        false,# supportTerminateDebuggee::Union{Nothing,Bool}
        false,# supportsDelayedStackTraceLoading::Union{Nothing,Bool}
        false,# supportsLoadedSourcesRequest::Union{Nothing,Bool}
        false,# supportsLogPoints::Union{Nothing,Bool}
        false,# supportsTerminateThreadsRequest::Union{Nothing,Bool}
        false,# supportsSetExpression::Union{Nothing,Bool}
        false,# supportsTerminateRequest::Union{Nothing,Bool}
        false,# supportsDataBreakpoints::Union{Nothing,Bool}
        false,# supportsReadMemoryRequest::Union{Nothing,Bool}
        false,# supportsDisassembleRequest::Union{Nothing,Bool}
    )
    send(InitializeResponse(r.seq + 1, r.seq, true, nothing, nothing, InitializeResponseBody(capabilities)), server)
end

function handle(r::Request{ConfigurationDoneRequestArguments}, server::DebugAdapterServer)
    send(ConfigurationDoneResponse(r.seq + 1, r.seq, true, nothing, nothing, ConfigurationDoneResponseBody()), server)
end

function handle(r::Request{LaunchRequestArguments}, server::DebugAdapterServer)
    if r.arguments.noDebug
    end
    if r.arguments.__restart
    end
    send(LaunchResponse(r.seq + 1, r.seq, true, nothing, nothing, LaunchResponseBody()), server)
end


function handle(r::Request{AttachRequestArguments}, server::DebugAdapterServer)
    if r.arguments.__restart
    end
    send(AttachResponse(r.seq + 1, r.seq, true, nothing, nothing, AttachResponseBody()), server)
end


function handle(r::Request{RestartRequestArguments}, server::DebugAdapterServer)
    restart(server)
    send(RestartResponse(r.seq + 1, r.seq, true, nothing, nothing, RestartResponseBody()), server)
end

function restart(server) end

function handle(r::Request{DisconnectRequestArguments}, server::DebugAdapterServer)
    if r.arguments.restart
        # part of restart sequence
    end
    if r.arguments.terminateDebuggee
    end
    send(DisconnectResponse(r.seq + 1, r.seq, true, nothing, nothing, DisconnectResponseBody()),server)
end

function handle(r::Request{TerminateRequestArguments}, server::DebugAdapterServer)
    if r.arguments.restart
        # part of restart sequence
    end
    return TerminateResponse(r.seq + 1, r.seq, true, nothing, nothing, TerminateResponseBody())
end

function handle(r::Request{ThreadsRequestArguments}, server::DebugAdapterServer)
    threads = Thread[]
    send(ThreadsResponse(r.seq + 1, r.seq, true, nothing, nothing, ThreadsResponseBody(threads)), server)
end

function handle(r::Request{TerminateThreadsRequestArguments}, server::DebugAdapterServer)
    for t in r.arguments.threadIds
        # kill thread
    end
    send(TerminateThreadsResponse(r.seq + 1, r.seq, true, nothing, nothing, TerminateThreadsResponseBody()), server)
end

function handle(r::Request{LoadedSourcesRequestArguments}, server::DebugAdapterServer) 
    sources = Source[]
    send(LoadedSourcesResponse(r.seq + 1, r.seq, true, nothing, nothing, LoadedSourcesResponseBody(sources)), server)
end

