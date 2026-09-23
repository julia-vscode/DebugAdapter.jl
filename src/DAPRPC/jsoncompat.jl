# Everything version-sensitive about our use of JSON.jl lives here, so that the
# assumptions we make about a given JSON.jl release are visible in one place.
#
# Read side: JSON 1.x parses objects into `JSON.Object` by default, while the
# rest of the package expects plain `Dict{String,Any}`, recursively.
_parse_json(value) = JSON.parse(value; dicttype=Dict{String,Any})

# Write side: we rely on `JSON.lower` (see `interface_def.jl`) being honored for
# our own types, and on `AbstractDict` serializing as a JSON object. Both hold
# for every version allowed by `[compat]`.
_json(value) = JSON.json(value)
