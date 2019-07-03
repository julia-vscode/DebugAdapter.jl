function handle(r::Request{SetBreakpointsRequestArguments}, server::DebugAdapterServer)
    bps = Breakpoint[]
    doc = getdoc(r.arguments.source, server)
    if r.arguments.sourceModified
        # adjust doc 
    end
    for bp in r.arguments.breakpoints
        # push!(bps, Breakpoint())
    end
    
    send(SetBreakpointsResponse(r.seq + 1, r.seq, true, nothing, nothing, SetBreakpointsResponseBody(bps)), server)
end

function getdoc(source::Source, server) end


function handle(r::Request{SetFunctionBreakpointsRequestArguments}, server::DebugAdapterServer)
    bps = Breakpoint[]
    
    for bp in r.arguments.breakpoints
        # push!(bps, Breakpoint())
    end
    
    send(SetFunctionBreakpointsResponse(r.seq + 1, r.seq, true, nothing, nothing, SetFunctionBreakpointsResponseBody(bps)), server)
end


function handle(r::Request{SetExceptionBreakpointsRequestArguments}, server::DebugAdapterServer)
    send(SetExceptionBreakpointsResponse(r.seq + 1, r.seq, true, nothing, nothing, SetExceptionBreakpointsResponseBody()), server)
end

function handle(r::Request{DataBreakpointsInfoRequestArguments}, server::DebugAdapterServer)
    dataId = nothing
    description = ""
    accessTypes = nothing
    canPersist = false
    send(DataBreakpointsInfoResponse(r.seq + 1, r.seq, true, nothing, nothing, DataBreakpointsInfoResponseBody(dataId, description, accessTypes, canPersist)), server)
end

function handle(r::Request{SetDataBreakpointsRequestArguments}, server::DebugAdapterServer)
    bps = Breakpoint[]
    for bp in r.arguments.breakpoints
        # push!(bps, Breakpoint())
    end
    send(SetDataBreakpointsResponse(r.seq + 1, r.seq, true, nothing, nothing, SetDataBreakpointsResponseBody(bps)), server)
end