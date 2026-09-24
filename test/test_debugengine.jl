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
