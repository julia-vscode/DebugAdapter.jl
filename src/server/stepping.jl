function handle!(server::Server, request::ContinueRequest)
    respond!(server, request, ContinueResponseBody(false))
end

function handle!(server::Server, request::NextRequest)
    respond!(server, request, NextResponseBody())
end

function handle!(server::Server, request::StepInRequest)
    respond!(server, request, StepInResponseBody())
end

function handle!(server::Server, request::StepOutRequest)
    respond!(server, request, StepOutResponseBody())
end

function handle!(server::Server, request::StepBackRequest)
    respond!(server, request, StepBackResponseBody())
end

function handle!(server::Server, request::ReverseContinueRequest)
    respond!(server, request, ReverseContinueResponseBody())
end

function handle!(server::Server, request::RestartFrameRequest)
    respond!(server, request, RestartFrameResponseBody())
end

function handle!(server::Server, request::GotoRequest)
     respond!(server, request, GotoResponseBody())
end

function handle!(server::Server, request::PauseRequest)
    respond!(server, request, PauseResponseBody())
end