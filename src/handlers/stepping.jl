function handle(r::Request{ContinueRequestArguments}, server::DebugAdapterServer)
    send(ContinueResponse(r.seq + 1, r.seq, true, nothing, nothing, ContinueResponseBody(false)), server)
end

function handle(r::Request{NextRequestArguments}, server::DebugAdapterServer)
    send(NextResponse(r.seq + 1, r.seq, true, nothing, nothing, NextResponseBody()), server)
end

function handle(r::Request{StepInRequestArguments}, server::DebugAdapterServer)
    send(StepInResponse(r.seq + 1, r.seq, true, nothing, nothing, StepInResponseBody()), server)
end

function handle(r::Request{StepOutRequestArguments}, server::DebugAdapterServer)
    send(StepOutResponse(r.seq + 1, r.seq, true, nothing, nothing, StepOutResponseBody()), server)
end

function handle(r::Request{StepBackRequestArguments}, server::DebugAdapterServer)
    send(StepBackResponse(r.seq + 1, r.seq, true, nothing, nothing, StepBackResponseBody()), server)
end

function handle(r::Request{ReverseContinueRequestArguments}, server::DebugAdapterServer)
    send(ReverseContinueResponse(r.seq + 1, r.seq, true, nothing, nothing, ReverseContinueResponseBody()), server)
end

function handle(r::Request{RestartFrameRequestArguments}, server::DebugAdapterServer)
    send(RestartFrameResponse(r.seq + 1, r.seq, true, nothing, nothing, RestartFrameResponseBody()), server)
end

function handle(r::Request{GotoRequestArguments}, server::DebugAdapterServer)
    send(GotoResponse(r.seq + 1, r.seq, true, nothing, nothing, GotoResponseBody()), server)
end

function handle(r::Request{PauseRequestArguments}, server::DebugAdapterServer)
    send(PauseResponse(r.seq + 1, r.seq, true, nothing, nothing, PauseResponseBody()), server)
end
 


# Introspection-y requests

function handle(r::Request{StackTraceRequestArguments}, server::DebugAdapterServer)
    sfs = StackFrame[]
    send(StackTraceResponse(r.seq + 1, r.seq, true, nothing, nothing, StackTraceResponseBody(sfs, length(sfs))), server)
end

function handle(r::Request{ScopesRequestArguments}, server::DebugAdapterServer)
    scopes = Scope[]
    send(ScopesResponse(r.seq + 1, r.seq, true, nothing, nothing, ScopesResponseBody(scopes)), server)
end

function handle(r::Request{VariablesRequestArguments}, server::DebugAdapterServer)
    variables = Variable[]
    r.arguments.variablesReference
    
    if r.arguments.start isa Int && 1 < r.arguments.start + 1 < length(variables)
        variables = variables[r.arguments.start + 1:end]
    end
    if r.arguments.count isa Int && r.arguments.count + 1 > 0 && length(variables) > 0
        variables = variables[1:min(length(variables), r.arguments.count + 1)]
    end
    send(VariablesResponse(r.seq + 1, r.seq, true, nothing, nothing, VariablesResponseBody(variables)), server)
end

function handle(r::Request{SetVariableRequestArguments}, server::DebugAdapterServer)
    value = ""
    type = ""
    variablesReference = nothing
    namedVariables = nothing
    indexedVariables = nothing
    send(SetVariableResponse(r.seq + 1, r.seq, true, nothing, nothing, SetVariableResponseBody(value, type, variablesReference, namedVariables, indexedVariables)), server)
end

function handle(r::Request{SourceRequestArguments}, server::DebugAdapterServer) 
    content = ""
    mimeType = "text/julia"
    send(SourceResponse(r.seq + 1, r.seq, true, nothing, nothing, SourceResponseBody(content, mimeType)), server)
end

function handle(r::Request{ModulesRequestArguments}, server::DebugAdapterServer) 
    modules = Module[]

    nmodules = length(modules)
    if r.arguments.startModule isa Int && 1 < r.arguments.start + 1 < length(modules)
        modules = modules[r.arguments.startModule + 1:end]
    end
    if r.arguments.moduleCount isa Int && r.arguments.moduleCount + 1 > 0 && length(modules) > 0
        modules = modules[1:min(length(modules), r.arguments.moduleCount + 1)]
    end
    send(ModulesResponse(r.seq + 1, r.seq, true, nothing, nothing, ModulesResponseBody(modules, nmodules)), server)
end

function handle(r::Request{EvaluateRequestArguments}, server::DebugAdapterServer) 
    result = ""
    type = ""
    presentationHint = nothing
    variablesReference = 0
    namedVariables = nothing
    indexedVariables = nothing
    memoryReference = nothing
    send(EvaluateResponse(r.seq + 1, r.seq, true, nothing, nothing, EvaluateResponseBody(result, type, presentationHint, variablesReference, namedVariables, indexedVariables, memoryReference)), server)
end

function handle(r::Request{SetExpressionRequestArguments}, server::DebugAdapterServer) 
    value = ""
    type = ""
    presentationHint = nothing
    variablesReference = 0
    namedVariables = nothing
    indexedVariables = nothing
    send(SetExpressionResponse(r.seq + 1, r.seq, true, nothing, nothing, SetExpressionResponseBody(value, type, presentationHint, variablesReference, namedVariables, indexedVariables)), server)
end

function handle(r::Request{StepInTargetsRequestArguments}, server::DebugAdapterServer) 
    targets = StepInTarget[]
    send(StepInTargetsResponse(r.seq + 1, r.seq, true, nothing, nothing, StepInTargetsResponseBody(targets)), server)
end

function handle(r::Request{GotoTargetsRequestArguments}, server::DebugAdapterServer) 
    targets = GotoTarget[]
    send(GotoTargetsResponse(r.seq + 1, r.seq, true, nothing, nothing, GotoTargetsResponseBody(targets)), server)
end

function handle(r::Request{CompletionsRequestArguments}, server::DebugAdapterServer) 
    targets = CompletionItem[]
    send(CompletionsResponse(r.seq + 1, r.seq, true, nothing, nothing, CompletionsResponseBody(targets)), server)
end

function handle(r::Request{ExceptionInfoRequestArguments}, server::DebugAdapterServer) 
    exceptionId = ""
    description = ""
    breakMode = ExceptionBreakModes[4]
    details = nothing
    send(ExceptionInfoResponse(r.seq + 1, r.seq, true, nothing, nothing, ExceptionInfoResponseBody(exceptionId, description, breakMode, details)), server)
end

function handle(r::Request{ReadMemoryRequestArguments}, server::DebugAdapterServer) 
    address = ""
    unreadableBytes = nothing
    data = nothing
    send(ReadMemoryResponse(r.seq + 1, r.seq, true, nothing, nothing, ReadMemoryResponseBody(address, unreadableBytes, data)), server)
end


function handle(r::Request{DisassembleRequestArguments}, server::DebugAdapterServer) 
    instructions = DisassembledInstruction[]
    send(DisassembleResponse(r.seq + 1, r.seq, true, nothing, nothing, DisassembleResponseBody(instructions)), server)
end
