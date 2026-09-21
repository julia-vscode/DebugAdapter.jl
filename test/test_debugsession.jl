@testsnippet DapClient begin
    import Sockets, JSON

    """
        with_debug_session(f) -> (events, result)

    Run a `DebugSession` over a pipe with a minimal DAP client attached, hand `f` the
    session so it can debug code on it, and return the events the client saw along with
    whatever `f` returned.

    The client is only as complete as these tests need: it completes the handshake and
    records every event it is sent.
    """
    function with_debug_session(f)
        # A loopback socket rather than the named pipe the real adapter is given, because
        # the session only ever sees an `IO` and a port needs no cleanup or platform case.
        port, server = Sockets.listenany(Sockets.localhost, 0)

        result = Ref{Any}(nothing)

        server_task = @async begin
            conn = Sockets.accept(server)
            session = DebugAdapter.DebugSession(conn)
            session_task = @async DebugAdapter.run(session)
            try
                result[] = f(session)
            finally
                close(session)
                wait(session_task)
            end
        end

        client = Sockets.connect(Sockets.localhost, port)
        events = String[]
        seq = Ref(0)

        function request(command, arguments=Dict{String,Any}())
            seq[] += 1
            payload = JSON.json(Dict{String,Any}(
                "seq" => seq[],
                "type" => "request",
                "command" => command,
                "arguments" => arguments,
            ))
            write(client, "Content-Length: $(sizeof(payload))\r\n\r\n", payload)
            flush(client)
        end

        reader = @async while isopen(client)
            line = readline(client, keep=false)
            startswith(line, "Content-Length:") || continue
            n = parse(Int, strip(split(line, ':')[2]))
            readline(client)  # the blank line between header and body
            msg = JSON.parse(String(read(client, n)))
            msg["type"] == "event" && push!(events, msg["event"])
        end

        try
            request("initialize", Dict{String,Any}("adapterID" => "julia"))
            # The handshake is only ordered by what the adapter waits on, and `attach`
            # fulfills what `debug_code` blocks on, so a short wait between the two is
            # enough to keep them in order.
            sleep(0.5)
            request("attach", Dict{String,Any}("stopOnEntry" => false))
            sleep(0.5)
            request("configurationDone", Dict{String,Any}())

            wait(server_task)
            sleep(0.5)
        finally
            close(client)
            close(server)
        end

        return (events, result[])
    end
end

@testitem "debug_code reports termination once per session, not once per chunk" setup=[DapClient] begin
    # `terminated` means the debuggee has ended, and a client that hears it ends the debug
    # session and disconnects. TestItemControllers debugs a test item's `@testsnippet`
    # setups and then its body as separate `debug_code` calls, so sending the event after
    # the setup tore the session down before the body ever ran and breakpoints in the body
    # were never hit (julia-testitems/TestItemRunner.jl#107).
    module TerminationTarget
        first_ran = false
        second_ran = false
    end

    events, _ = with_debug_session() do session
        DebugAdapter.debug_code(session, TerminationTarget, "first_ran = true\n", "setup.jl"; notify_termination=false)
        DebugAdapter.debug_code(session, TerminationTarget, "second_ran = true\n", "body.jl")
    end

    # Both chunks ran, in the same session
    @test TerminationTarget.first_ran == true
    @test TerminationTarget.second_ran == true

    @test count(==("terminated"), events) == 1
end

@testitem "debug_code reports termination by default" setup=[DapClient] begin
    module DefaultTerminationTarget
        ran = false
    end

    events, _ = with_debug_session() do session
        DebugAdapter.debug_code(session, DefaultTerminationTarget, "ran = true\n", "body.jl")
    end

    @test DefaultTerminationTarget.ran == true
    @test count(==("terminated"), events) == 1
end

@testitem "code that cannot be parsed ends the session with a message, not a crash" setup=[DapClient] begin
    # An unparseable file has nothing to step through, which is the state of the user's
    # code rather than a defect here. It used to escape `run` as
    # `ErrorException("Invalid expression")`, out of the session loop and into the REPL's
    # crash handler, so the user got a crash report and no explanation. It now reaches
    # the debug console, and the session is still there for whatever is debugged next.
    module UnparseableTarget
        ran = false
    end

    events, _ = with_debug_session() do session
        DebugAdapter.debug_code(session, UnparseableTarget, "function f(
", "broken.jl"; notify_termination=false)
        DebugAdapter.debug_code(session, UnparseableTarget, "ran = true
", "body.jl")
    end

    @test count(==("output"), events) == 1
    @test UnparseableTarget.ran == true
    @test count(==("terminated"), events) == 1
end

@testitem "initialize clears file breakpoints left over from an earlier session" begin
    import JuliaInterpreter

    # The REPL-hosted debugger serves many sessions from one process, and the client only
    # sends `setBreakpoints` for files that still have breakpoints. A file whose breakpoints
    # were all deleted between sessions is therefore never mentioned again, so unless the
    # adapter clears the process-global registry itself the deleted breakpoints keep firing
    # for the rest of the REPL's life (julialang.org discourse #138981).
    JuliaInterpreter.remove()

    target = joinpath(@__DIR__, "stale_breakpoint_target.jl")
    JuliaInterpreter.breakpoint(target, 2)
    @test any(bp -> bp isa JuliaInterpreter.BreakpointFileLocation, JuliaInterpreter.breakpoints())

    # A new session's first request, with no `setBreakpoints` following it.
    session = DebugAdapter.DebugSession(IOBuffer())
    DebugAdapter.initialize_request(session, DebugAdapter.InitializeRequestArguments(adapterID="julia"))

    @test !any(bp -> bp isa JuliaInterpreter.BreakpointFileLocation, JuliaInterpreter.breakpoints())
end

@testitem "setBreakpoints removes previous breakpoints for a non-normalized source path" begin
    import JuliaInterpreter

    # `JuliaInterpreter.breakpoint` stores the normalized path, so the removal pass has to
    # compare against the normalized form of `source.path` or it matches nothing and leaves
    # the old breakpoints behind.
    JuliaInterpreter.remove()

    target = joinpath(@__DIR__, "sub", "..", "breakpoint_target.jl")
    source = DebugAdapter.Source(path=target)

    DebugAdapter.set_break_points_request(
        DebugAdapter.DebugSession(IOBuffer()),
        DebugAdapter.SetBreakpointsArguments(source=source, breakpoints=[DebugAdapter.SourceBreakpoint(line=2)])
    )
    @test count(bp -> bp isa JuliaInterpreter.BreakpointFileLocation, JuliaInterpreter.breakpoints()) == 1

    # The client now reports that the file has no breakpoints left.
    DebugAdapter.set_break_points_request(
        DebugAdapter.DebugSession(IOBuffer()),
        DebugAdapter.SetBreakpointsArguments(source=source, breakpoints=DebugAdapter.SourceBreakpoint[])
    )
    @test count(bp -> bp isa JuliaInterpreter.BreakpointFileLocation, JuliaInterpreter.breakpoints()) == 0
end
