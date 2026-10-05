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

@testitem "DAP ids that are a number or a string accept parsed JSON numbers" begin
    import JSON

    _parse = DebugAdapter.DAPRPC._parse_json

    # JSON numbers parse as `Int64` even on 32-bit Julia, and the dict constructor hands
    # a number-or-string field over unconverted. Declared with `Int`, these fields threw a
    # `MethodError` there. The type checks keep the test meaningful on 64-bit, too.
    @test fieldtype(DebugAdapter.DAModule, :id) == Union{Int64,String}
    @test fieldtype(DebugAdapter.StackFrame, :moduleId) == Union{Missing,Int64,String}

    numbered_module = DebugAdapter.DAModule(_parse("{\"id\":5,\"name\":\"Base\"}"))
    @test numbered_module.id === Int64(5)
    @test _parse(JSON.json(numbered_module)) == Dict{String,Any}("id" => 5, "name" => "Base")
    @test DebugAdapter.DAModule(_parse("{\"id\":\"Base\",\"name\":\"Base\"}")).id == "Base"

    numbered_frame = DebugAdapter.StackFrame(_parse("{\"id\":1,\"name\":\"f\",\"line\":3,\"column\":1,\"moduleId\":5}"))
    @test numbered_frame.moduleId === Int64(5)
    @test _parse(JSON.json(numbered_frame))["moduleId"] == 5
    @test DebugAdapter.StackFrame(_parse("{\"id\":1,\"name\":\"f\",\"line\":3,\"column\":1,\"moduleId\":\"Base\"}")).moduleId == "Base"
end

@testitem "integer fields of DAP types accept parsed JSON numbers" begin
    # JSON numbers parse as `Int64`. A field declared with `Int` only takes one on 32-bit
    # Julia, where `Int` is `Int32`, if `Int` is its only member besides `Missing`. In a
    # union with anything else there is no `convert`. This can only fail on 32-bit legs.
    union_members(T) = T isa Union ? vcat(union_members(T.a), union_members(T.b)) : Any[T]
    is_integer_type(T) = T isa DataType && T <: Integer && T !== Bool

    unconvertible = String[]
    for name in names(DebugAdapter, all=true)
        isdefined(DebugAdapter, name) || continue
        T = getfield(DebugAdapter, name)
        (T isa DataType && T <: DebugAdapter.Outbound && !isabstracttype(T)) || continue
        for i in 1:fieldcount(T)
            field_type = fieldtype(T, i)
            any(is_integer_type, union_members(field_type)) || continue
            converts = try
                convert(field_type, Int64(1)) == 1
            catch
                false
            end
            converts || push!(unconvertible, string(T, ".", fieldname(T, i)))
        end
    end
    @test unconvertible == String[]
end

@testitem "JSON version under test" begin
    import JSON

    # `pkgversion` postdates the Julia versions this package supports, so fall
    # back to reading the version out of the loaded package's Project.toml.
    # Line-based, because the TOML stdlib is not there on Julia 1.0 either.
    function loaded_json_version()
        isdefined(Base, :pkgversion) && return string(Base.pkgversion(JSON))
        project = joinpath(dirname(dirname(pathof(JSON))), "Project.toml")
        for line in readlines(project)
            m = match(r"^version\s*=\s*\"(.*)\"", strip(line))
            m === nothing || return m.captures[1]
        end
        error("No version found in $project")
    end

    # Set by the `Julia CI (JSON 0.20)` workflow. `Pkg.test` resolves in its own
    # sandbox environment, which the manifest check there cannot see, so this is
    # the only place that can confirm which JSON.jl version the suite actually
    # ran against.
    expected = get(ENV, "DEBUGADAPTER_EXPECTED_JSON_VERSION", "")
    if !isempty(expected)
        @test startswith(loaded_json_version(), expected * ".")
    end
end
