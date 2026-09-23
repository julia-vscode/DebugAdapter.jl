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
