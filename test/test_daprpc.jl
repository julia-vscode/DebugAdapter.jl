@testsnippet DapEndpointPair begin
    import Sockets

    """
        endpoint_pair() -> (client, adapter, cleanup)

    Two `DAPEndpoint`s wired to each other over a loopback socket, both already
    running, plus a function that tears the pair down.
    """
    function endpoint_pair()
        port, server = Sockets.listenany(Sockets.localhost, 0)
        client_conn = Sockets.connect(Sockets.localhost, port)
        adapter_conn = Sockets.accept(server)

        client = DebugAdapter.DAPRPC.DAPEndpoint(client_conn, client_conn)
        adapter = DebugAdapter.DAPRPC.DAPEndpoint(adapter_conn, adapter_conn)
        run(client)
        run(adapter)

        return client, adapter, () -> begin
            close(client)
            close(adapter)
            close(server)
        end
    end
end

@testitem "DAPRPC routes responses back to the caller" setup=[DapEndpointPair] begin
    client, adapter, cleanup = endpoint_pair()

    try
        succeeded = Ref{Any}(nothing)
        request_task = @async succeeded[] = DebugAdapter.DAPRPC.send_request(client, "runInTerminal", Dict{String,Any}())

        incoming = DebugAdapter.DAPRPC.get_next_message(adapter)
        @test incoming["type"] == "request"
        @test incoming["command"] == "runInTerminal"

        DebugAdapter.DAPRPC.send_success_response(adapter, incoming, Dict{String,Any}("processId" => 17))
        wait(request_task)
        @test succeeded[]["processId"] == 17

        failure = Ref{Any}(nothing)
        failing_task = @async try
            DebugAdapter.DAPRPC.send_request(client, "evaluate", Dict{String,Any}())
        catch err
            failure[] = err
        end

        incoming = DebugAdapter.DAPRPC.get_next_message(adapter)
        DebugAdapter.DAPRPC.send_error_response(adapter, incoming, 42, "boom", nothing)
        wait(failing_task)
        @test failure[] isa DebugAdapter.DAPRPC.DAPError
        @test failure[].msg == "boom"
        # The whole `Message` survives the round trip, not just its text.
        @test failure[].code == 42
        @test failure[].data === nothing

        with_variables = Ref{Any}(nothing)
        variables_task = @async try
            DebugAdapter.DAPRPC.send_request(client, "evaluate", Dict{String,Any}())
        catch err
            with_variables[] = err
        end

        incoming = DebugAdapter.DAPRPC.get_next_message(adapter)
        DebugAdapter.DAPRPC.send_error_response(adapter, incoming, 7, "no such variable", Dict("name" => "x"))
        wait(variables_task)
        @test with_variables[].code == 7
        @test with_variables[].data == Dict("name" => "x")
    finally
        cleanup()
    end
end

@testitem "DAPRPC error responses are valid DAP" begin
    import Sockets

    # A bare socket on the far end, so that the exact bytes `send_error_response`
    # puts on the wire can be inspected rather than an endpoint's view of them.
    port, server = Sockets.listenany(Sockets.localhost, 0)
    peer = Sockets.connect(Sockets.localhost, port)
    conn = Sockets.accept(server)

    endpoint = DebugAdapter.DAPRPC.DAPEndpoint(conn, conn)
    run(endpoint)

    try
        request = Dict{String,Any}("seq" => 3, "type" => "request", "command" => "evaluate")
        DebugAdapter.DAPRPC.send_error_response(endpoint, request, 42, "boom", nothing)

        header = readline(peer)
        @test startswith(header, "Content-Length:")
        length_of_body = parse(Int, strip(split(header, ':')[2]))
        readline(peer)  # the blank line between header and body
        response = DebugAdapter.DAPRPC._parse_json(String(read(peer, length_of_body)))

        @test response["type"] == "response"
        @test response["success"] === false
        @test response["command"] == "evaluate"
        @test response["request_seq"] == 3
        @test response["message"] == "boom"
        @test response["body"]["error"]["id"] == 42
        @test response["body"]["error"]["format"] == "boom"
        # `data` was `nothing`, and DAP has no null-valued `variables`.
        @test !haskey(response["body"]["error"], "variables")
    finally
        close(endpoint)
        close(peer)
        close(server)
    end
end

@testitem "DAPRPC tolerates error responses without a structured message" begin
    # `body.error` is optional in DAP, so a peer may send only the short
    # `message`, and the id and variables are then simply not available.
    minimal = DebugAdapter.DAPRPC.dap_error(Dict{String,Any}("success" => false, "message" => "cancelled"))
    @test minimal.msg == "cancelled"
    @test minimal.code == -32603
    @test minimal.data === nothing
end
