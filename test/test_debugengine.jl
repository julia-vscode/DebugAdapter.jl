@testitem "Run some code" begin
    import DebugAdapter.DebugEngines

    module TestValue
        x = "Code didn't run"
    end

    de = DebugEngines.DebugEngine(
        TestValue,
        "x = true",
        "foo.jl",
        false,
        a -> println("a called")
    )

    run(de)

    @test TestValue.x == true
end

@testitem "Code that is not parseable is reported, not crashed on" begin
    import DebugAdapter.DebugEngines

    module NotParsed
        x = "Code didn't run"
    end

    de = DebugEngines.DebugEngine(
        NotParsed,
        "function f(",
        "broken.jl",
        false,
        a -> println("a called")
    )

    # The state of the user's file, not a defect: it carries the file it is
    # about, so the caller can say which one could not be debugged.
    err = try
        run(de)
        nothing
    catch e
        e
    end

    @test err isa DebugEngines.InvalidExpressionError
    @test occursin("broken.jl", sprint(showerror, err))
    @test occursin("not valid Julia code", sprint(showerror, err))
    @test NotParsed.x == "Code didn't run"
end

@testitem "Code whose first expression cannot be loaded is reported, not crashed on" begin
    import DebugAdapter.DebugEngines

    module FirstNotLoaded
        y = "Code didn't run"
    end

    # `L"..."` without `using LaTeXStrings`: the macro only fails to resolve when the
    # expression is lowered, which is after parsing succeeded.
    de = DebugEngines.DebugEngine(
        FirstNotLoaded,
        "y = L\"a\"\n",
        "hw1.jl",
        false,
        a -> println("a called")
    )

    err = try
        run(de)
        nothing
    catch e
        e
    end

    # The state of the user's file, like unparseable code: it carries the file and the
    # error Julia gave, which is what `include` would have shown them.
    @test err isa DebugEngines.CodeLoadError
    @test err isa DebugEngines.UserCodeError
    @test err.filename == "hw1.jl"
    @test err.error isa LoadError
    @test occursin("hw1.jl", sprint(showerror, err))
    @test occursin("@L_str", sprint(showerror, err))
    @test FirstNotLoaded.y == "Code didn't run"
end

@testitem "Code whose later expression cannot be loaded is reported, not crashed on" begin
    import DebugAdapter.DebugEngines

    module LaterNotLoaded
        x = "Code didn't run"
        y = "Code didn't run"
        z = "Code didn't run"
    end

    de = DebugEngines.DebugEngine(
        LaterNotLoaded,
        "x = 1\ny = L\"a\"\nz = 2\n",
        "hw1.jl",
        false,
        a -> println("a called")
    )

    # Each top-level expression is lowered only once the one before it has run, so this
    # fails while the debuggee is already running, not when it starts.
    err = try
        run(de)
        nothing
    catch e
        e
    end

    @test err isa DebugEngines.CodeLoadError
    @test err.error isa LoadError
    @test occursin("@L_str", sprint(showerror, err))
    @test LaterNotLoaded.x == 1
    @test LaterNotLoaded.y == "Code didn't run"
    @test LaterNotLoaded.z == "Code didn't run"
end

@testsnippet PausedEngine begin
    import DebugAdapter.DebugEngines
    import JuliaInterpreter

    # Runs `code`, saved as a real file so file breakpoints can match it, in an engine
    # configured the way the extension does by default, and reports each stop on `stops`,
    # which is closed once the run ends.
    function start_paused_engine(code, breakpoint_lines)
        JuliaInterpreter.remove()
        file = joinpath(mktempdir(), "paused.jl")
        write(file, code)
        for line in breakpoint_lines
            JuliaInterpreter.breakpoint(file, line)
        end

        stops = Channel{Any}(Inf)
        de = DebugEngines.DebugEngine(Module(:Paused), code, file, false, (reason, _...) -> put!(stops, reason))
        # `ALL_MODULES_EXCEPT_MAIN` can never be applied for good, so it is retried after
        # every step, which is the path that used to throw away the paused framecodes.
        DebugEngines.set_compiled_functions_modules!(de, ["ALL_MODULES_EXCEPT_MAIN"])
        task = @async try
            run(de)
        finally
            close(stops)
        end
        return de, file, stops, task
    end

    next_stop(stops) = try
        take!(stops)
    catch err
        err isa InvalidStateException || rethrow()
        :finished
    end

    paused_line(de) = de.frame === nothing ? nothing : JuliaInterpreter.linenumber(JuliaInterpreter.leaf(de.frame))

    const PAUSED_CODE = """
    function f()
        x = 1
        y = 2
        z = 3
        return x + y + z
    end
    f()
    """
end

@testitem "a breakpoint added while paused is hit" setup=[PausedEngine] begin
    de, file, stops, task = start_paused_engine(PAUSED_CODE, [2])
    try
        @test next_stop(stops) == DebugEngines.StopReasonBreakpoint
        @test paused_line(de) == 2

        JuliaInterpreter.breakpoint(file, 4)
        DebugEngines.execution_continue(de)

        @test next_stop(stops) == DebugEngines.StopReasonBreakpoint
        @test paused_line(de) == 4

        DebugEngines.execution_continue(de)
        @test next_stop(stops) == :finished
    finally
        DebugEngines.terminate(de)
        wait(task)
        JuliaInterpreter.remove()
    end
end

@testitem "a breakpoint removed while paused is not hit" setup=[PausedEngine] begin
    de, file, stops, task = start_paused_engine(PAUSED_CODE, [2, 4])
    try
        @test next_stop(stops) == DebugEngines.StopReasonBreakpoint
        @test paused_line(de) == 2

        for bp in copy(JuliaInterpreter.breakpoints())
            bp isa JuliaInterpreter.BreakpointFileLocation && bp.line == 4 && JuliaInterpreter.remove(bp)
        end
        DebugEngines.execution_continue(de)

        @test next_stop(stops) == :finished
    finally
        DebugEngines.terminate(de)
        wait(task)
        JuliaInterpreter.remove()
    end
end
