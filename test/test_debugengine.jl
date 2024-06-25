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
