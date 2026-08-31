@testitem "DAP protocol JSON serialization" begin
    import JSON

    _parse = DebugAdapter.DAPRPC._parse_json

    empty_event = DebugAdapter.InitializedEventArguments()
    @test _parse(JSON.json(empty_event)) === nothing

    # A type whose fields are all optional and all missing must still serialize
    # as an object, not as `null` or an error.
    @test JSON.json(DebugAdapter.Source()) == "{}"
    @test JSON.json(DebugAdapter.ValueFormat()) == "{}"

    source = DebugAdapter.Source(name="example.jl", path="/tmp/example.jl")
    output = DebugAdapter.OutputEventArguments(
        category="stdout",
        output="hello\n",
        source=source,
        line=12,
    )

    serialized = _parse(JSON.json(output))
    @test serialized == Dict{String,Any}(
        "category" => "stdout",
        "output" => "hello\n",
        "source" => Dict{String,Any}(
            "name" => "example.jl",
            "path" => "/tmp/example.jl",
        ),
        "line" => 12,
    )
    @test !haskey(serialized, "variablesReference")
    @test !haskey(serialized["source"], "sourceReference")

    # Missing fields are omitted at every level of nesting, including inside
    # arrays of protocol objects.
    nested = DebugAdapter.Source(
        name="parent.jl",
        sources=[DebugAdapter.Source(name="child.jl", sourceReference=7)],
    )
    nested_json = _parse(JSON.json(nested))
    @test nested_json == Dict{String,Any}(
        "name" => "parent.jl",
        "sources" => Any[Dict{String,Any}("name" => "child.jl", "sourceReference" => 7)],
    )
end

@testitem "DAP protocol objects accept parsed JSON dictionaries" begin
    import JSON

    parsed = JSON.parse("""
        {
            "name": "parent.jl",
            "sources": [
                {"name": "child.jl", "sourceReference": 7}
            ]
        }
        """)

    source = DebugAdapter.Source(parsed)
    @test source.name == "parent.jl"
    @test source.path === missing
    # Indexing rather than `only`, which postdates the Julia versions this
    # package supports.
    @test length(source.sources) == 1
    @test source.sources[1].name == "child.jl"
    @test source.sources[1].sourceReference == 7

    normalized = DebugAdapter.DAPRPC._parse_json("{\"type\":\"event\",\"body\":{}}")
    @test normalized isa Dict{String,Any}
    @test normalized["body"] isa Dict{String,Any}
end

@testitem "JSON version under test" begin
    import JSON

    # Set by the `json-compat` CI job. `Pkg.test` resolves in its own sandbox
    # environment, so this is the only place that can confirm which JSON.jl
    # version the suite actually ran against.
    expected = get(ENV, "DEBUGADAPTER_EXPECTED_JSON_VERSION", "")
    if !isempty(expected)
        @test startswith(string(pkgversion(JSON)), expected * ".")
    end
end
