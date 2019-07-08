function handle!(server::Server, request::SetBreakpointsRequest)
    bps = Breakpoint[]
    if request.arguments.sourceModified
        # adjust doc
    end
    for bp in request.arguments.breakpoints
        # push!(bps, Breakpoint())
    end

    respond!(server, request, SetBreakpointsResponseBody(bps))
end

function handle!(server::Server, request::SetDataBreakpointsRequest)
    bps = Breakpoint[]
    for bp in request.arguments.breakpoints
        # push!(bps, Breakpoint())
    end
    respond!(server, request, SetDataBreakpointsResponseBody(bps))
end

function handle!(server::Server, request::SetExceptionBreakpointsRequest)
    respond!(server, request, SetExceptionBreakpointsResponseBody())
end

function handle!(server::Server, request::SetFunctionBreakpointsRequest)
    bps = Breakpoint[]

    for bp in request.arguments.breakpoints
        # push!(bps, Breakpoint())
    end

    respond!(server, request, SetFunctionBreakpointsResponseBody(bps))
end

function handle!(server::Server, request::DataBreakpointInfoRequest)
    dataId = missing
    description = ""
    accessTypes = missing
    canPersist = false
    body = DataBreakpointInfoResponseBody(dataId, description, accessTypes, canPersist)
    respond!(server, request, body)
end
