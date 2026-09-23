# Rewrites the JSON entry in the [compat] section of Project.toml to "0.20" so
# that every subsequent resolve can only pick JSON 0.20.x — the last JSON
# version without non-stdlib dependencies, which is what the VS Code extension
# uses on every Julia version.
#
# This must run on Julia 1.0 (no TOML stdlib), so the file is edited line by
# line, tracking the current section: [deps] also has a `JSON = "<uuid>"` line
# that must be left alone.

function force_json_020()
    lines = readlines("Project.toml")
    section = ""
    replaced = false
    for i in eachindex(lines)
        stripped = strip(lines[i])
        if startswith(stripped, "[")
            section = stripped
        elseif section == "[compat]" && occursin(r"^JSON\s*=", stripped)
            lines[i] = "JSON = \"0.20\""
            replaced = true
        end
    end
    replaced || error("No JSON entry found in the [compat] section of Project.toml")
    open("Project.toml", "w") do io
        for line in lines
            println(io, line)
        end
    end
    println("Restricted Project.toml compat to JSON = \"0.20\"")
end

force_json_020()
