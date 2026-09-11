@testsnippet HostileValues begin
    # Everything a `variables` response renders is produced by calling into the debuggee's
    # own code, which is free to be broken. Each fixture below breaks one of those calls,
    # and each failure message is distinctive so the tests can assert that the *reason*
    # reaches the client rather than merely that something went wrong.
    #
    # The fixtures misbehave only while `HOSTILE[]` is set, which `hostile` does for the
    # duration of the request under test. Outside that window they behave, so that when a
    # test fails Test can print the exception, its backtrace and the values involved without
    # re-entering the broken `show` or `showerror` it is trying to report.
    const HOSTILE = Ref(false)
    broken(what) = HOSTILE[] ? error("$what is broken") : nothing

    function hostile(f)
        HOSTILE[] = true
        try
            return f()
        finally
            HOSTILE[] = false
        end
    end

    struct ThrowingShow end
    Base.show(io::IO, ::ThrowingShow) = (broken("show"); print(io, "ThrowingShow()"))

    struct ThrowingTypeShow end
    Base.show(io::IO, ::Type{ThrowingTypeShow}) = (broken("type show"); print(io, "ThrowingTypeShow"))

    struct HasThrowingField
        x::ThrowingShow
        y::Int
    end

    struct HasThrowingTypeField
        x::ThrowingTypeShow
    end

    # Only a field that isn't concrete-and-immutable can actually be left `#undef`.
    mutable struct HasUndefField
        x::Any
        y::Any
        HasUndefField() = new()
    end

    struct ThrowingGetindexArray <: AbstractArray{Int,1} end
    Base.size(::ThrowingGetindexArray) = (3,)
    Base.IndexStyle(::Type{ThrowingGetindexArray}) = IndexLinear()
    Base.getindex(::ThrowingGetindexArray, i::Int) = (i == 2 && broken("getindex"); i)

    struct ThrowingSizeArray <: AbstractArray{Int,1} end
    Base.size(::ThrowingSizeArray) = (broken("size"); (3,))
    Base.IndexStyle(::Type{ThrowingSizeArray}) = IndexLinear()
    Base.getindex(::ThrowingSizeArray, i::Int) = i

    struct ThrowingKey end
    Base.show(io::IO, ::ThrowingKey) = (broken("key show"); print(io, "ThrowingKey()"))

    struct ThrowingDict <: AbstractDict{Any,Int} end
    Base.keys(::ThrowingDict) = Any[ThrowingKey(), :ok]
    Base.length(::ThrowingDict) = 2
    Base.getindex(::ThrowingDict, k) = k === :ok ? 42 : (broken("getindex"); 0)
    Base.iterate(d::ThrowingDict, state = 1) =
        state > 2 ? nothing : (keys(d)[state] => d[keys(d)[state]], state + 1)

    # An `AbstractDict` that has fields is reported through a synthetic "Fields" child node.
    struct DictWithThrowingField <: AbstractDict{Symbol,Int}
        bad::ThrowingShow
    end
    Base.keys(::DictWithThrowingField) = Symbol[]
    Base.length(::DictWithThrowingField) = 0
    Base.iterate(::DictWithThrowingField, state = 1) = nothing

    # An exception whose own `showerror` is broken, so that rendering the *error* fails too.
    struct BrokenError <: Exception end
    Base.showerror(io::IO, ::BrokenError) = (broken("showerror"); print(io, "BrokenError"))

    struct ThrowsBrokenError end
    Base.show(io::IO, ::ThrowsBrokenError) =
        HOSTILE[] ? throw(BrokenError()) : print(io, "ThrowsBrokenError()")

    struct HasThrowingErrorField
        x::ThrowsBrokenError
    end

    module HostileModule
        struct Bad end

        # `names` is sorted, so the unrenderable binding is reached before the good one.
        const a_bad = Bad()
        const z_good = 42
    end
    Base.show(io::IO, ::Type{HostileModule.Bad}) = (broken("module type show"); print(io, "Bad"))

    """Session holding `value` as variable reference 1."""
    function session_for(value, kind = :var)
        session = DebugAdapter.DebugSession(IOBuffer())
        push!(session.varrefs, DebugAdapter.VariableReference(kind, value))
        return session
    end

    """The variables a client would see for reference `ref` of `session`."""
    function variables_of(session, ref = 1; kwargs...)
        return hostile() do
            DebugAdapter.variables_request(
                session,
                DebugAdapter.VariablesArguments(variablesReference = ref; kwargs...)
            ).variables
        end
    end

    variables_for(value, kind = :var; kwargs...) =
        variables_of(session_for(value, kind); kwargs...)

    named(variables, name) = variables[findfirst(v -> v.name == name, variables)]
end

@testitem "variables of a value whose type printing throws" setup=[HostileValues] begin
    # `construct_return_msg_for_var` guarded `show` but not `string(typeof(value))`, which
    # runs the same user-defined printing code and took the whole request down with it.
    variables = variables_for(HasThrowingTypeField(ThrowingTypeShow()))

    @test length(variables) == 1
    @test occursin("type show is broken", variables[1].type)
end

@testitem "variables of a struct whose field cannot be shown" setup=[HostileValues] begin
    variables = variables_for(HasThrowingField(ThrowingShow(), 2))

    @test length(variables) == 2
    @test occursin("show is broken", named(variables, "x").value)
    # A broken sibling must not cost the fields that render perfectly well.
    @test named(variables, "y").value == "2"
end

@testitem "variables of an array whose getindex throws for one element" setup=[HostileValues] begin
    variables = variables_for(ThrowingGetindexArray())

    @test length(variables) == 3
    @test variables[1].value == "1"
    @test occursin("getindex is broken", variables[2].value)
    @test variables[3].value == "3"
end

@testitem "variables of an array whose size throws" setup=[HostileValues] begin
    # Nothing can be enumerated at all here, so the response says so — and says why.
    variables = variables_for(ThrowingSizeArray())

    @test length(variables) == 1
    @test occursin("doesn't implement the expected interface", variables[1].value)
    @test occursin("size is broken", variables[1].value)
end

@testitem "variables of a dict whose key and getindex throw" setup=[HostileValues] begin
    # The fallback for a failed element built its name with `i.I`, which only exists on a
    # `CartesianIndex` — so for a dict the fallback threw too, and the entries after the
    # bad key were never reported.
    variables = variables_for(ThrowingDict())

    @test length(variables) == 2
    @test occursin("key show is broken", variables[1].name)
    @test occursin("getindex is broken", variables[1].value)
    @test variables[2].name == ":ok"
    @test variables[2].value == "42"
end

@testitem "variables of a struct with undefined fields" setup=[HostileValues] begin
    # An undefined field is normal, not a failure, and keeps reporting itself as such.
    variables = variables_for(HasUndefField())

    @test length(variables) == 2
    @test all(v -> v.value == "#undef", variables)
end

@testitem "variables of a module containing an unrenderable value" setup=[HostileValues] begin
    # One unrenderable binding used to truncate the listing at that name, hiding every
    # binding sorted after it.
    variables = variables_for(HostileModule, :module)

    @test occursin("module type show is broken", named(variables, "a_bad").type)
    @test named(variables, "z_good").value == "42"
end

@testitem "variables of an unrenderable value under Fields" setup=[HostileValues] begin
    session = session_for(DictWithThrowingField(ThrowingShow()))

    top = variables_of(session)
    @test length(top) == 1
    fields = top[1]
    @test fields.name == "Fields"

    variables = variables_of(session, fields.variablesReference)
    @test length(variables) == 1
    @test occursin("show is broken", named(variables, "bad").value)
end

@testitem "variables of a value whose error cannot be shown either" setup=[HostileValues] begin
    # Reporting the reason means calling `showerror` on an exception that came out of user
    # code, which can be just as broken as the `show` that raised it.
    variables = variables_for(HasThrowingErrorField(ThrowsBrokenError()))

    @test length(variables) == 1
    @test occursin("BrokenError", variables[1].value)
end

@testitem "exception info for an exception whose showerror throws" setup=[HostileValues] begin
    # This request fires on every uncaught-exception stop, and both the id and the
    # description are rendered from the user's own exception object.
    session = DebugAdapter.DebugSession(IOBuffer())
    session.debug_engine = DebugAdapter.DebugEngines.DebugEngine(
        Main, "", "test.jl", false, (args...) -> nothing
    )
    session.debug_engine.last_exception = BrokenError()

    response = hostile() do
        DebugAdapter.exception_info_request(
            session,
            DebugAdapter.ExceptionInfoArguments(threadId = 1)
        )
    end

    @test occursin("BrokenError", response.exceptionId)
    @test response.description isa String
end

@testitem "setVariable with a stale variable reference reports an error" begin
    # The varrefs are cleared on every stop, so a reference from a previous stop names
    # nothing. Reporting that relies on `DAPError` being in scope here at all.
    result = DebugAdapter.set_variable_request(
        DebugAdapter.DebugSession(IOBuffer()),
        DebugAdapter.SetVariableArguments(variablesReference = 99, name = "x", value = "1")
    )

    @test result isa DebugAdapter.DAPError
end
