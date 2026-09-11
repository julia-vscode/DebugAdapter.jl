@testsnippet DapRpcEndpoint begin
    import JSON

    """
        dispatching(handler) -> (endpoint, dispatcher)

    An endpoint that queues its outgoing messages instead of writing them, with `handler`
    bound to the `threads` request. `threads` takes no arguments, so nothing about these
    tests depends on argument deserialisation.

    The endpoint is marked running by hand rather than by `run`ing it: over an `IOBuffer`
    the read task would hit EOF at once and close the endpoint, racing the test.
    """
    function dispatching(handler)
        endpoint = DebugAdapter.DAPRPC.DAPEndpoint(IOBuffer(), IOBuffer())
        endpoint.status = :running

        dispatcher = DebugAdapter.DAPRPC.MsgDispatcher()
        dispatcher[DebugAdapter.threads_request_type] = handler

        return endpoint, dispatcher
    end

    threads_request(seq = 7) =
        Dict{String,Any}("seq" => seq, "type" => "request", "command" => "threads")

    """The message the client would receive, parsed, or `nothing` if none was queued."""
    function sent(endpoint)
        # `take!` on an empty channel blocks forever, and with no other task to run that
        # is a silent hang of the test process rather than a failure.
        isready(endpoint.out_msg_queue) || return nothing
        return JSON.parse(take!(endpoint.out_msg_queue))
    end
end

@testitem "a request whose handler throws still gets a response" setup=[DapRpcEndpoint] begin
    # Without this the client waits on a response that never comes: for `variables`, a
    # debug pane that spins for the rest of the session.
    endpoint, dispatcher = dispatching(params -> error("handler is broken"))

    # The error is still raised after responding, so that `run`'s error handler reports it.
    @test_throws ErrorException DebugAdapter.DAPRPC.dispatch_msg(
        endpoint, dispatcher, threads_request()
    )

    response = sent(endpoint)
    @test response["type"] == "response"
    @test response["success"] == false
    @test response["request_seq"] == 7
    @test response["command"] == "threads"
    @test occursin("handler is broken", response["message"])
end

@testitem "a handler returning a DAPError gets an error response" setup=[DapRpcEndpoint] begin
    endpoint, dispatcher = dispatching(params -> DebugAdapter.DAPError("nope"))

    DebugAdapter.DAPRPC.dispatch_msg(endpoint, dispatcher, threads_request())

    response = sent(endpoint)
    @test response["type"] == "response"
    @test response["success"] == false
    @test response["command"] == "threads"
    @test response["message"] == "nope"
    @test response["body"]["error"]["format"] == "nope"
end

@testitem "a failed request is answered exactly once" setup=[DapRpcEndpoint] begin
    # The wrong-return-type branch responds and *then* raises, so the catch-all must not
    # answer a second time.
    endpoint, dispatcher = dispatching(params -> "not a threads response")

    @test_throws ErrorException DebugAdapter.DAPRPC.dispatch_msg(
        endpoint, dispatcher, threads_request()
    )

    response = sent(endpoint)
    @test response["success"] == false
    @test !isready(endpoint.out_msg_queue)
end
