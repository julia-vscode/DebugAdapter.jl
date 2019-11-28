# *** helpers for jsonable ***

"""
Applies any relevant `property => field` renamings to the given property
"""
function field_to_property(property::Symbol, prs::Pair{Symbol,Symbol}...)
    field = property
    for pr in prs
        field = field == pr[1] ? pr[2] : field
    end
    field
end

"""
Like `field_to_property`, but applies the rules in reverse.
"""
function property_to_field(field::Symbol, prs::Pair{Symbol,Symbol}...)
    property = field
    for pr in prs
        property = property == pr[2] ? pr[1] : property
    end
    property
end

"""
Converts/filters an associative container to a `Dict{Symbol,Any}` that can be splatted
into a keyword-based function. Additional key-to-argument pairs may be given to translate
dictionary keys to the corresponding argument name to which its value should apply.
The associative container must have keys that can be converted to `Symbol`s.
"""
function kwargs(assoc, argnames, prs...)
    argname(k) = property_to_field(Symbol(k), prs...)
    Dict{Symbol,Any}(argname(k)=>v for (k,v) in assoc if argname(k) ∈ argnames)
end

"""
Returns an instance of `JSON.Writer.CompositeTypeWrapper` which will emit only the
properties whose values satisfy !ismissing. If all properties are missing, returns
`missing`.
"""
function json_lower_omit_missings(x)
    syms = filter(k->!ismissing(getproperty(x,k)), collect(propertynames(x)))
    isempty(syms) ? missing : JSON.Writer.CompositeTypeWrapper(x, syms)
end

"""
Defines and exports a composite data type that is serializable to and from JSON.

It constructs a keyword-based constructor, using `Base.@kwdef`, and a constructor from a
Dict---which itself uses the keyword-based constructor---along with a custom definition of
`JSON.lower` which omits emitting key-value pairs for properties whose value is `missing`.
Note that a value of `nothing` will result in the explicit emission of a null value.

More explicitly, to declare an optional field of type `T`, use `Union{Missing,T}`, and, to
capture an explicit null value in the JSON, use `nothing`. Here are some examples of
translating TypeScript field declarations into the appropriate Julia type:

    TypeScript                            Julia
    ----------                            -----
    maybeString?: string | null   ====>   maybeString::Union{Missing, Nothing, String}
    stringOrNull: string | null   ====>   stringOrNull::Union{Nothing, String}
    maybeSomething?: any          ====>   maybeSomething::Any  # `Union` not needed here

Also note that the `Base.@kwdef` macro allows for declaring default values for fields.
_E.g._, you can declare a field whose TypeScript description is `maybeBool?: boolean` as:

    maybeBool::Union{Missing, Bool} = missing

If additional property remappings are appended in the form of `:property => :field` pairs,
it also defines appropriate custom methods for `propertynames` and `getproperty`.

_E.g._:

    @jsonable struct Blah{X, Y} <: Z
        ...
    end :a=>:b :p=>:q

becomes:

    Base.@kwdef struct Blah{X, Y} <: Z
        ...
    end
    export Blah

    function Blah{X, Y}(d::Dict) where {X, Y}
        Blah{X, Y}(;kwargs(d, fieldnames(Blah), :a=>:b, :p=>:q)...)
    end

    JSON.lower(x::Blah) = json_lower_omit_missings(x)

    Base.propertynames(x::Blah) = map(f->field_to_property(f, :a=>:b, :p=>:q), fieldnames(Blah))
    Base.getproperty(x::Blah, s::Symbol) = getfield(x, property_to_field(s, :a=>:b, :p=>:q))

# Sidenote on the use of `Missing`.

The Julia language documentation suggests using the `Some` wrapper to disambiguate
situations where `nothing` is to be interpreted as a value that is present but happens to
take the `nothing` value, while a bare value of `nothing` is to be interpreted as a missing
value. However, using `Some` would greatly complicate serialization to and from JSON. And,
while both `nothing` and `missing` both serialize to `null` in JSON, `null` parses to
`nothing`, so there is no loss of JSON expressiveness in reserving the `missing` value for
the purpose of disambiguation.
"""
macro jsonable(structdefn, prs...)
    structname = structdefn.args[2]
    if structname isa Expr && structname.head == :<:
        structname = structname.args[1]
    end
    barename = structname isa Expr ? structname.args[1] : structname
    kwargexpr = :(kwargs(d, fieldnames($barename)))
    append!(kwargexpr.args, prs)
    ctor = :(function $structname(d::Dict)
                $structname(;$kwargexpr...)
             end)
    if structname isa Expr
        ctor.args[1] = Expr(:where, ctor.args[1], structname.args[2:end]...)
    end
    ex = quote
        Base.@kwdef $structdefn
        export $barename
        $ctor
        JSON.lower(x::$barename) = json_lower_omit_missings(x)
    end
    if length(prs) > 0
        push!(ex.args, :(Base.propertynames(x::$barename) = map(f->field_to_property(f, $(prs...)), fieldnames($barename))))
        push!(ex.args, :(Base.getproperty(x::$barename, s::Symbol) = getfield(x, property_to_field(s, $(prs...)))))
    end
    esc(ex)
end
