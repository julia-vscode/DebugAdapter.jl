function handle!(server::Server, request::InitializeRequest)
    server.last_seq = request.seq
    capabilities = Capabilities(
        false, # supportsConfigurationDoneRequest::Union{Missing,Bool} = missing
        false, # supportsFunctionBreakpoints::Union{Missing,Bool} = missing
        false, # supportsConditionalBreakpoints::Union{Missing,Bool} = missing
        false, # supportsHitConditionalBreakpoints::Union{Missing,Bool} = missing
        false, # supportsEvaluateForHovers::Union{Missing,Bool} = missing
        ExceptionBreakpointsFilter[], # exceptionBreakpointFilters::Union{Missing,Vector{ExceptionBreakpointsFilter}} = missing
        false, # supportsStepBack::Union{Missing,Bool} = missing
        false, # supportsSetVariable::Union{Missing,Bool} = missing
        false, # supportsRestartFrame::Union{Missing,Bool} = missing
        false, # supportsGotoTargetsRequest::Union{Missing,Bool} = missing
        false, # supportsStepInTargetsRequest::Union{Missing,Bool} = missing
        false, # supportsCompletionsRequest::Union{Missing,Bool} = missing
        false, # supportsModulesRequest::Union{Missing,Bool} = missing
        ColumnDescriptor[], # additionalModuleColumns::Union{Missing,Vector{ColumnDescriptor}} = missing
        ChecksumAlgorithm["MD5", "SHA1", "SHA256"], # supportedChecksumAlgorithms::Union{Missing,Vector{ChecksumAlgorithm}} = missing
        false, # supportsRestartRequest::Union{Missing,Bool} = missing
        false, # supportsExceptionOptions::Union{Missing,Bool} = missing
        false, # supportsValueFormattingOptions::Union{Missing,Bool} = missing
        false, # supportsExceptionInfoRequest::Union{Missing,Bool} = missing
        false, # supportTerminateDebuggee::Union{Missing,Bool} = missing
        false, # supportsDelayedStackTraceLoading::Union{Missing,Bool} = missing
        false, # supportsLoadedSourcesRequest::Union{Missing,Bool} = missing
        false, # supportsLogPoints::Union{Missing,Bool} = missing
        false, # supportsTerminateThreadsRequest::Union{Missing,Bool} = missing
        false, # supportsSetExpression::Union{Missing,Bool} = missing
        false, # supportsTerminateRequest::Union{Missing,Bool} = missing
        false, # supportsDataBreakpoints::Union{Missing,Bool} = missing
        false, # supportsReadMemoryRequest::Union{Missing,Bool} = missing
        false, # supportsDisassembleRequest::Union{Missing,Bool} = missing
        missing
    )
    server.state = INITIALIZED
    respond!(server, request, capabilities)
    signal!(server, InitializedEventBody())
end

function handle!(server::Server, request::ConfigurationDoneRequest)
    server.state.CONFIGURED
    respond!(server, request, ConfigurationDoneResponseBody())
end

function handle!(server::Server, request::AttachRequest)
    if request.arguments.__restart
    end
    respond!(server, request, AttachResponseBody())
end

function handle!(server::Server, request::LaunchRequest)
    respond!(server, request, LaunchResponseBody())
end



function handle!(server::Server, request::RestartRequest)
    restart(server)
    respond!(server, request, RestartResponseBody())
end

function restart(server::Server) end

function handle!(server::Server, request::DisconnectRequest)
    if request.arguments.restart
        # part of restart sequence
    end
    respond!(server, request, DisconnectResponseBody())
    if request.arguments.terminateDebuggee === true
        exit()
    end
end

function handle!(server::Server, request::TerminateRequest)
    if request.arguments.restart
        # part of restart sequence
    end
    respond!(server, request, TerminateResponseBody())
end

function handle!(server::Server, request::ThreadsRequest)
    threads = Thread[]
    respond!(server, request, ThreadsResponseBody(threads))
end

function handle!(server::Server, request::TerminateThreadsRequest)
    for t in request.arguments.threadIds
        # kill thread
    end
    respond!(server, request, TerminateThreadsResponseBody())
end

function handle!(server::Server, request::LoadedSourcesRequest)
    sources = Source[]
    respond!(server, request, LoadedSourcesResponseBody(sources))
end
