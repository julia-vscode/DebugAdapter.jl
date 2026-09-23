# Fails loudly unless the resolved Manifest.toml has JSON at version 0.20.x,
# so a silent fallback to a newer JSON cannot go unnoticed after
# force_json_020.jl tightened the compat bound.
#
# Must run on Julia 1.0 (no TOML stdlib): scans the manifest line by line for
# the JSON stanza, handling both manifest formats — `[[JSON]]` (old) and
# `[[deps.JSON]]` (Julia >= 1.6.2).

function verify_json_020()
    in_json_stanza = false
    for line in readlines("Manifest.toml")
        stripped = strip(line)
        if startswith(stripped, "[")
            in_json_stanza = stripped == "[[JSON]]" || stripped == "[[deps.JSON]]"
        elseif in_json_stanza
            m = match(r"^version\s*=\s*\"(.*)\"", stripped)
            if m !== nothing
                version = m.captures[1]
                if startswith(version, "0.20.")
                    println("JSON resolved to version ", version)
                    return
                else
                    error("JSON resolved to version $version, expected 0.20.x")
                end
            end
        end
    end
    error("No JSON version found in Manifest.toml")
end

verify_json_020()
