function handle!(server::Server, request::InitializeRequest)
    capabilities = Capabilities(
        true, # supportsConfigurationDoneRequest::Union{Missing,Bool} = missing
        true, # supportsFunctionBreakpoints::Union{Missing,Bool} = missing
        true, # supportsConditionalBreakpoints::Union{Missing,Bool} = missing
        true, # supportsHitConditionalBreakpoints::Union{Missing,Bool} = missing
        true, # supportsEvaluateForHovers::Union{Missing,Bool} = missing
        ExceptionBreakpointsFilter[], # exceptionBreakpointFilters::Union{Missing,Vector{ExceptionBreakpointsFilter}} = missing
        true, # supportsStepBack::Union{Missing,Bool} = missing
        true, # supportsSetVariable::Union{Missing,Bool} = missing
        true, # supportsRestartFrame::Union{Missing,Bool} = missing
        true, # supportsGotoTargetsRequest::Union{Missing,Bool} = missing
        true, # supportsStepInTargetsRequest::Union{Missing,Bool} = missing
        true, # supportsCompletionsRequest::Union{Missing,Bool} = missing
        true, # supportsModulesRequest::Union{Missing,Bool} = missing
        ColumnDescriptor[], # additionalModuleColumns::Union{Missing,Vector{ColumnDescriptor}} = missing
        ChecksumAlgorithm["MD5", "SHA1", "SHA256"], # supportedChecksumAlgorithms::Union{Missing,Vector{ChecksumAlgorithm}} = missing
        true, # supportsRestartRequest::Union{Missing,Bool} = missing
        true, # supportsExceptionOptions::Union{Missing,Bool} = missing
        true, # supportsValueFormattingOptions::Union{Missing,Bool} = missing
        true, # supportsExceptionInfoRequest::Union{Missing,Bool} = missing
        true, # supportTerminateDebuggee::Union{Missing,Bool} = missing
        true, # supportsDelayedStackTraceLoading::Union{Missing,Bool} = missing
        true, # supportsLoadedSourcesRequest::Union{Missing,Bool} = missing
        true, # supportsLogPoints::Union{Missing,Bool} = missing
        true, # supportsTerminateThreadsRequest::Union{Missing,Bool} = missing
        true, # supportsSetExpression::Union{Missing,Bool} = missing
        true, # supportsTerminateRequest::Union{Missing,Bool} = missing
        true, # supportsDataBreakpoints::Union{Missing,Bool} = missing
        true, # supportsReadMemoryRequest::Union{Missing,Bool} = missing
        true # supportsDisassembleRequest::Union{Missing,Bool} = missing
    )
    server.state.state = INITIALIZED
    respond!(server, request, capabilities)
    signal!(server, IntializedEventBody())
end

function handle!(server::Server, request::ConfigurationDoneRequest)
    server.state.state.CONFIGURED
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
    if request.arguments.terminateDebuggee
    end
    respond!(server, request, DisconnectResponseBody())
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
