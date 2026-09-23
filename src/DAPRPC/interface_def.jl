abstract type Outbound end

# Optional DAP fields are represented as `missing` and must be omitted from the
# wire format entirely, rather than serialized as `null`.
#
# We lower to a `Dict{String,Any}` rather than to a `NamedTuple` of the present
# fields: a `NamedTuple` would mint a distinct concrete type for every subset of
# non-missing fields, forcing the JSON writer to compile a fresh specialization
# for each shape a type happens to take. Types like `StackFrame` and `Variable`
# are sent with varying field sets while stepping, so that cost is paid over and
# over during an interactive session. A `Dict` also serializes as `{}` when no
# field is present, which every supported JSON.jl version handles.
function JSON.lower(a::Outbound)
    nfields(a) == 0 && return nothing

    result = Dict{String,Any}()
    for field in fieldnames(typeof(a))
        value = getfield(a, field)
        ismissing(value) || (result[String(field)] = value)
    end
    return result
end

function field_allows_missing(field::Expr)
    field.head == :(::) && field.args[2] isa Expr &&
    field.args[2].head == :curly && field.args[2].args[1] == :Union &&
    any(i -> i == :Missing, field.args[2].args)
end

function field_type(field::Expr, typename::String)
    if field.args[2] isa Expr && field.args[2].head == :curly && field.args[2].args[1] == :Union
        if length(field.args[2].args) == 3 && (field.args[2].args[2] == :Missing || field.args[2].args[3] == :Missing)
            return field.args[2].args[2] == :Missing ? field.args[2].args[3] : field.args[2].args[2]
        else
            # We return Any for now, which will lead to no type conversion
            return :Any
        end
    else
        return field.args[2]
    end
end

function get_kwsignature_for_field(field::Expr)
    fieldname = field.args[1]
    fieldtype = field.args[2]
    default_value = field_allows_missing(field) ? missing : :(error("You must provide a value for the $fieldname field."))

    return Expr(:kw, Expr(Symbol("::"), fieldname, fieldtype), default_value)
end

macro dict_readable(arg)
    tname = arg.args[2] isa Expr ? arg.args[2].args[1] : arg.args[2]
    count_real_fields = count(field -> !(field isa LineNumberNode), arg.args[3].args)
    ex = quote
        $((arg))

        $(count_real_fields > 0 ? :(
        function $tname(; $((get_kwsignature_for_field(field) for field in arg.args[3].args if !(field isa LineNumberNode))...))
            $tname($((field.args[1] for field in arg.args[3].args if !(field isa LineNumberNode))...))
        end
        ) : nothing)

        function $tname(dict::AbstractDict)
        end
    end

    fex = :($((tname))())
    for field in arg.args[3].args
        if !(field isa LineNumberNode)
            fieldname = string(field.args[1])
            fieldtype = field_type(field, string(tname))
            if fieldtype isa Expr && fieldtype.head == :curly && fieldtype.args[1] == :Dict
                f = :($fieldtype(dict[$fieldname]))
            elseif fieldtype isa Expr && fieldtype.head == :curly && fieldtype.args[2] != :Any
                f = :($(fieldtype.args[2]).(dict[$fieldname]))
            elseif fieldtype != :Any
                f = :($(fieldtype)(dict[$fieldname]))
            else
                f = :(dict[$fieldname])
            end
            if field_allows_missing(field)
                f = :(haskey(dict, $fieldname) ? $f : missing)
            end
            push!(fex.args, f)
        end
    end
    push!(ex.args[end].args[2].args, fex)
    return esc(ex)
end
