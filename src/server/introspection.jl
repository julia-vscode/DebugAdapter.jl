function handle!(server::Server, request::StackTraceRequest)
    sfs = StackFrame[]
    respond!(server, request, StackTraceResponseBody(sfs, length(sfs)))
end

function handle!(server::Server, request::ScopesRequest)
    scopes = Scope[]
    respond!(server, request, ScopesResponseBody(scopes))
end

function handle!(server::Server, request::VariablesRequest)
    variables = Variable[]
    request.arguments.variablesReference

    if request.arguments.start isa Int && 1 < request.arguments.start + 1 < length(variables)
        variables = variables[r.arguments.start + 1:end]
    end
    if request.arguments.count isa Int && request.arguments.count + 1 > 0 && length(variables) > 0
        variables = variables[1:min(length(variables), request.arguments.count + 1)]
    end
    respond!(server, request, VariablesResponseBody(variables))
end

function handle!(server::Server, request::SetVariableRequest)
    value = ""
    type = ""
    respond!(server, request, SetVariableResponseBody(value, type))
end

function handle!(server::Server, request::SourceRequest)
    content = ""
    mimeType = "text/julia"
    respond!(server, request, SourceResponseBody(content, mimeType))
end

function handle!(server::Server, request::ModulesRequest)
    modules = Module[]

    nmodules = length(modules)
    if request.arguments.startModule isa Int && 1 < request.arguments.start + 1 < length(modules)
        modules = modules[r.arguments.startModule + 1:end]
    end
    if request.arguments.moduleCount isa Int && request.arguments.moduleCount + 1 > 0 && length(modules) > 0
        modules = modules[1:min(length(modules), request.arguments.moduleCount + 1)]
    end
    respond!(server, request, ModulesResponseBody(modules, nmodules))
end

function handle!(server::Server, request::EvaluateRequest)
    result = ""
    type = ""
    variablesReference = 0
    respond!(server, request, EvaluateResponseBody(result, type, variablesReference))
end

function handle!(server::Server, request::SetExpressionRequest)
    value = ""
    type = ""
    variablesReference = 0
    respond!(server, request, SetExpressionResponseBody(value, type, variablesReference))
end

function handle!(server::Server, request::StepInTargetsRequest)
    targets = StepInTarget[]
    respond!(server, request, StepInTargetsResponseBody(targets))
end

function handle!(server::Server, request::GotoTargetsRequest)
    targets = GotoTarget[]
    respond!(server, request, GotoTargetsResponseBody(targets))
end

function handle!(server::Server, request::CompletionsRequest)
    targets = CompletionItem[]
    respond!(server, request, CompletionsResponseBody(targets))
end

function handle!(server::Server, request::ExceptionInfoRequest)
    exceptionId = ""
    description = ""
    breakMode = ExceptionBreakModes[4]
    respond!(server, request, ExceptionInfoResponseBody(exceptionId, description, breakMode))
end

function handle!(server::Server, request::ReadMemoryRequest)
    address = ""
    respond!(server, request, ReadMemoryResponseBody(address))
end


function handle!(server::Server, request::DisassembleRequest)
    instructions = DisassembledInstruction[]
    respond!(server, request, DisassembleResponseBody(instructions))
end
