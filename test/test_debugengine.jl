@testitem "Run some code" begin
    import DebugAdapter.DebugEngines
    using .DebugEngines: DebugEngine

    de = DebugEngine(
        Main,
        "println(\"Hello world\")",
        "foo.jl",
        false,
        a -> println("a called")
    )

    run(de)
end
