# Request handlers

function initialize_request(debug_session::DebugSession, params::InitializeRequestArguments)
    # The REPL-hosted debugger runs many sessions in one process (VSCodeServer's
    # `start_debug_backend`), and JuliaInterpreter's breakpoint registry is process-global.
    # The client only sends `setBreakpoints` for files that still have breakpoints, so a file
    # whose breakpoints were all deleted between sessions is never mentioned again and its
    # stale breakpoints would keep firing. Start every session from a clean slate; the client
    # re-sends the full, current set during the configuration phase that follows.
    # (Function breakpoints get the same treatment in `DebugEngines.set_function_breakpoints!`.)
    for bp in copy(JuliaInterpreter.breakpoints())
        bp isa JuliaInterpreter.BreakpointFileLocation && JuliaInterpreter.remove(bp)
    end

    return Capabilities(
        true, # supportsConfigurationDoneRequest::Union{Missing,Bool}
        true, # supportsFunctionBreakpoints::Union{Missing,Bool}
        true, #supportsConditionalBreakpoints::Union{Missing,Bool}
        false, # supportsHitConditionalBreakpoints::Union{Missing,Bool}
        true, # supportsEvaluateForHovers::Union{Missing,Bool}
        ExceptionBreakpointsFilter[ExceptionBreakpointsFilter("error", "Uncaught Exceptions", true), ExceptionBreakpointsFilter("throw", "All Exceptions", false)], # exceptionBreakpointFilters::Vector{ExceptionBreakpointsFilter}
        false, # supportsStepBack::Union{Missing,Bool}
        true, # supportsSetVariable::Union{Missing,Bool}
        true, # supportsRestartFrame::Union{Missing,Bool}
        missing, # supportsGotoTargetsRequest::Union{Missing,Bool}
        true, # supportsStepInTargetsRequest::Union{Missing,Bool}
        false, # supportsCompletionsRequest::Union{Missing,Bool}
        missing, # supportsModulesRequest::Union{Missing,Bool}
        ColumnDescriptor[], #additionalModuleColumns::Vector{ColumnDescriptor}
        ChecksumAlgorithm[], # supportedChecksumAlgorithms::Vector{ChecksumAlgorithm}
        missing, # supportsRestartRequest::Union{Missing,Bool}
        missing, # supportsExceptionOptions::Union{Missing,Bool}
        missing, #supportsValueFormattingOptions::Union{Missing,Bool}
        true, # supportsExceptionInfoRequest::Union{Missing,Bool}
        missing, # supportTerminateDebuggee::Union{Missing,Bool}
        missing, # supportsDelayedStackTraceLoading::Union{Missing,Bool}
        missing, # supportsLoadedSourcesRequest::Union{Missing,Bool}
        false, # supportsLogPoints::Union{Missing,Bool}
        missing, # supportsTerminateThreadsRequest::Union{Missing,Bool}
        missing, #supportsSetExpression::Union{Missing,Bool}
        true, # supportsTerminateRequest::Union{Missing,Bool}
        false, # supportsDataBreakpoints::Union{Missing,Bool}
        missing, # supportsReadMemoryRequest::Union{Missing,Bool}
        missing # supportsDisassembleRequest::Union{Missing,Bool}
    )

        # response.body.supportsCancelRequest = false

        # response.body.supportsBreakpointLocationsRequest = false

        # response.body.supportsConditionalBreakpoints = true
end

function configuration_done_request(debug_session::DebugSession, params::Union{Nothing,ConfigurationDoneArguments})
    put!(debug_session.configuration_done, true)
    return ConfigurationDoneResponseArguments()
end

function launch_request(debug_session::DebugSession, params::JuliaLaunchArguments)
    # Indicate that we are ready for the initial configuration phase, and then
    # wait for it to finish
    DAPRPC.send(debug_session.endpoint, initialized_notification_type, InitializedEventArguments())
    take!(debug_session.configuration_done)

    params.project!==missing && Pkg.activate(params.project)

    empty!(ARGS)
    if params.args!==missing
        for arg in params.args
            push!(ARGS, arg)
        end
    end

    if params.cwd!==missing
        cd(params.cwd)
    end

    if params.env!==missing
        for i in params.env
            ENV[i.first] = i.second
        end
    end

    if params.noDebug === true
        filename_to_debug = isabspath(params.program) ? params.program : joinpath(pwd(), params.program)
        put!(debug_session.next_cmd, (cmd = :run, program = filename_to_debug))

        return LaunchResponseArguments()
    else
        @debug "debug_request" params = params

        filename_to_debug = isabspath(params.program) ? params.program : joinpath(pwd(), params.program)

        @debug "We are debugging the file $filename_to_debug."

        file_content = if params.code !== missing
            params.code
        else
            try
                read(filename_to_debug, String)
            catch err
                put!(debug_session.next_cmd, (cmd=:terminate,))
                return DAPError("Debugger failed to read the file `$filename_to_debug`.\n\n$(sprint(showerror, err))")
            end
        end

        if params.compiledModulesOrFunctions !== missing
            debug_session.compiled_modules_or_functions = params.compiledModulesOrFunctions
        end

        if params.compiledMode !== missing
            debug_session.compiled_mode = params.compiledMode
        end

        params.stopOnEntry!==missing && (debug_session.stop_on_entry = params.stopOnEntry)

        put!(debug_session.next_cmd, (cmd=:debug, mod=Main, code=file_content, filename=filename_to_debug))

        return LaunchResponseArguments()
    end
end

function attach_request(debug_session::DebugSession, params::JuliaAttachArguments)
    @debug "attach_request" params = params

    # Indicate that we are ready for the initial configuration phase, and then
    # wait for it to finish
    DAPRPC.send(debug_session.endpoint, initialized_notification_type, InitializedEventArguments())
    take!(debug_session.configuration_done)

    params.stopOnEntry!==missing && (debug_session.stop_on_entry = params.stopOnEntry)

    if params.compiledModulesOrFunctions !== missing
        debug_session.compiled_modules_or_functions = params.compiledModulesOrFunctions
    end

    if params.compiledMode !== missing
        debug_session.compiled_mode = params.compiledMode
    end

    if params.code !== missing
        filename_to_debug = if params.program !== missing
            isabspath(params.program) ? params.program : joinpath(pwd(), params.program)
        else
            joinpath(pwd(), "##unknown-file.jl")
        end
        put!(debug_session.next_cmd, (cmd=:debug, mod=Main, code=params.code, filename=filename_to_debug))
    else
        put!(debug_session.attached, true)
    end

    return AttachResponseArguments()
end



function set_compiled_items_request(debug_session::DebugSession, params::SetCompiledItemsArguments)
    @debug "set_compiled_items_request"

    debug_session.compiled_modules_or_functions = params.compiledModulesOrFunctions

    if debug_session.debug_engine!==nothing
        DebugEngines.set_compiled_functions_modules!(debug_session.debug_engine, debug_session.compiled_modules_or_functions)
    end
end

function set_compiled_mode_request(debug_session::DebugSession, params::SetCompiledModeArguments)
    @debug "set_compiled_mode_request"

    debug_session.compiled_mode = params.compiledMode

    if debug_session.debug_engine!==nothing
        DebugEngines.set_compiled_mode!(debug_session.debug_engine, debug_session.compiled_mode)
    end
end

function set_break_points_request(debug_session::DebugSession, params::SetBreakpointsArguments)
    @debug "setbreakpoints_request"

    filename = params.source.path
    # `JuliaInterpreter.breakpoint` normalizes the path it is handed and stores that, so the
    # removal below has to compare against the normalized form or it silently matches nothing
    # and leaves the old breakpoints in place.
    normalized_filename = normpath(filename)

    # JuliaInterpreter.remove mutates the vector returned by
    # breakpoints(), so we make a copy to not mess up iteration
    for bp in copy(JuliaInterpreter.breakpoints())
        if bp isa JuliaInterpreter.BreakpointFileLocation
            if bp.path == normalized_filename
                @debug "Removing breakpoint at $(bp.path):$(bp.line)"
                JuliaInterpreter.remove(bp)
            end
        end
    end

    for bp in params.breakpoints
        condition = bp.condition === missing ? nothing : try
            Meta.parse(bp.condition)
        catch err
            @debug "Invalid BP condition: `$(bp.condition)`. Falling back to always breaking." exception = err
            nothing
        end

        @debug "Setting breakpoint at $(filename):$(bp.line) (condition $(condition))"
        JuliaInterpreter.breakpoint(filename, bp.line, condition)
    end

    SetBreakpointsResponseArguments([Breakpoint(true) for _ in params.breakpoints])
end

function set_exception_break_points_request(debug_session::DebugSession, params::SetExceptionBreakpointsArguments)
    @debug "setexceptionbreakpoints_request"

    opts = Set(params.filters)

    if "error" in opts
        JuliaInterpreter.break_on(:error)
    else
        JuliaInterpreter.break_off(:error)
    end

    if "throw" in opts
        JuliaInterpreter.break_on(:throw)
    else
        JuliaInterpreter.break_off(:throw)
    end

    return SetExceptionBreakpointsResponseArguments(String[], missing)
end

function set_function_break_points_request(debug_session::DebugSession, params::SetFunctionBreakpointsArguments)
    @debug "setfunctionbreakpoints_request"

    bps = map(params.breakpoints) do i
        decoded_name = i.name
        decoded_condition = i.condition

        parsed_condition = try
            decoded_condition == "" ? nothing : Meta.parse(decoded_condition)
        catch err
            @debug "invalid condition: `$(decoded_condition)`. falling back to always breaking." exception = err
            nothing
        end

        try
            parsed_name = Meta.parse(decoded_name)

            if parsed_name isa Symbol
                return (mod = Main, name = parsed_name, signature = nothing, condition = parsed_condition)
            elseif parsed_name isa Expr
                if parsed_name.head == :.
                    # TODO Support this case
                    return nothing
                elseif parsed_name.head == :call
                    all_args_are_legit = true
                    if length(parsed_name.args) > 1
                        for arg in parsed_name.args[2:end]
                            if !(arg isa Expr) || arg.head != Symbol("::") || length(arg.args) != 1
                                all_args_are_legit = false
                            end
                        end
                        if all_args_are_legit

                            return (mod = Main, name = parsed_name.args[1], signature = map(j -> j.args[1], parsed_name.args[2:end]), condition = parsed_condition)
                        else
                            return (mod = Main, name = parsed_name.args[1], signature = nothing, condition = parsed_condition)
                        end
                    else
                        return (mod = Main, name = parsed_name.args[1], signature = nothing, condition = parsed_condition)
                    end
                else
                    return nothing
        end
            else
                return nothing
            end
        catch err
            return nothing
        end

        return nothing
    end

    bps = filter(i -> i !== nothing, bps)

    debug_session.function_breakpoints = bps

    if debug_session.debug_engine!==nothing
        DebugEngines.set_function_breakpoints!(debug_session.debug_engine, debug_session.function_breakpoints)
    end

    return SetFunctionBreakpointsResponseArguments([Breakpoint(true) for i = 1:length(bps)])
end

function sfHint(frame, meth_or_mod_name)
    if endswith(meth_or_mod_name, "#kw")
        return "subtle"
    end
    return missing
end

function stack_trace_request(debug_session::DebugSession, params::StackTraceArguments)
    @debug "getstacktrace_request"

    frames = StackFrame[]
    # TODO Move all of this into DebugEngine
    fr = debug_session.debug_engine.frame

    if fr === nothing
        @debug fr
        return StackTraceResponseArguments(frames, length(frames))
    end

    curr_fr = JuliaInterpreter.leaf(fr)

    id = 1
    while curr_fr !== nothing
        curr_scopeof = JuliaInterpreter.scopeof(curr_fr)
        curr_whereis = JuliaInterpreter.whereis(curr_fr)
        curr_mod = JuliaInterpreter.moduleof(curr_fr)

        file_name = curr_whereis[1]
        lineno = curr_whereis[2]
        meth_or_mod_name = string(Base.nameof(curr_fr))

        # Is this a file from base?
        if !isabspath(file_name) && !occursin(r"REPL\[\d*\]", file_name)
            file_name = basepath(file_name)
        end

        sf_hint = sfHint(fr, meth_or_mod_name)
        source_hint, source_origin = missing, missing # could try to de-emphasize certain sources in the future

        if startswith(basename(file_name), "jl_notebook_cell_df34fa98e69747e1a8f8a730347b8e2f_")
            push!(
                frames,
                StackFrame(
                    id,
                    meth_or_mod_name,
                    Source(
                        file_name,
                        file_name,
                        missing,
                        source_hint,
                        source_origin,
                        missing,
                        missing,
                        missing
                    ),
                    lineno,
                    0,
                    missing,
                    missing,
                    missing,
                    missing,
                    sf_hint
                )
            )
        elseif isfile(file_name)
            push!(
                frames,
                StackFrame(
                    id,
                    meth_or_mod_name,
                    Source(
                        basename(file_name),
                        file_name,
                        missing,
                        source_hint,
                        source_origin,
                        missing,
                        missing,
                        missing
                    ),
                    lineno,
                    0,
                    missing,
                    missing,
                    missing,
                    missing,
                    sf_hint
                )
            )
        elseif curr_scopeof isa Method
            ret = JuliaInterpreter.CodeTracking.definition(String, curr_fr.framecode.scope)
            if ret !== nothing
                source_name = string(curr_fr.framecode.scope)

                DebugEngines.set_source(debug_session.debug_engine, source_name, ret[1])
                source_id = DebugEngines.get_source_id(debug_session.debug_engine, source_name)

                push!(
                    frames,
                    StackFrame(
                        id,
                        meth_or_mod_name,
                        Source(
                            file_name,
                            missing,
                            source_id,
                            source_hint,
                            source_origin,
                            missing,
                            missing,
                            missing
                        ),
                        lineno,
                        0,
                        missing,
                        missing,
                        missing,
                        missing,
                        sf_hint
                    )
                )
            else
                src = curr_fr.framecode.src
                @static if isdefined(JuliaInterpreter, :copy_codeinfo)
                    src = JuliaInterpreter.copy_codeinfo(src)
                else
                    src = copy(src)
                end
                JuliaInterpreter.replace_coretypes!(src; rev = true)
                code = Base.invokelatest(JuliaInterpreter.framecode_lines, src)

                source_name = string(UUIDs.uuid4())

                DebugEngines.set_source(debug_session.debug_engine, source_name, join(code, '\n'))
                source_id = DebugEngines.get_source_id(debug_session.debug_engine, source_name)

                push!(
                    frames,
                    StackFrame(
                        id,
                        meth_or_mod_name,
                        Source(
                            file_name,
                            missing,
                            source_id,
                            source_hint,
                            source_origin,
                            missing,
                            missing,
                            missing
                        ),
                        lineno,
                        0,
                        missing,
                        missing,
                        missing,
                        missing,
                        sf_hint
                    )
                )
            end
        elseif occursin(r"REPL\[\d*\]", file_name)
            source_name = file_name
            source_id = DebugEngines.get_source_id(debug_session.debug_engine, file_name)

            push!(
                    frames,
                    StackFrame(
                        id,
                        meth_or_mod_name,
                        Source(
                            file_name,
                            missing,
                            source_id,
                            missing,
                            missing,
                            missing,
                            missing,
                            missing
                        ),
                        lineno,
                        0,
                        missing,
                        missing,
                        missing,
                        missing,
                        missing
                    )
                )
        else
            error("Unknown stack type")
        end

        id += 1
        curr_fr = curr_fr.caller
    end

    return StackTraceResponseArguments(frames, length(frames))
end

function scopes_request(debug_session::DebugSession, params::ScopesArguments)
    @debug "getscope_request"

    curr_fr = JuliaInterpreter.leaf(debug_session.debug_engine.frame)

    i = 1

    while params.frameId > i
        curr_fr = curr_fr.caller
        i += 1
    end

    curr_scopeof = JuliaInterpreter.scopeof(curr_fr)
    curr_whereis = JuliaInterpreter.whereis(curr_fr)

    file_name = curr_whereis[1]
    code_range = curr_scopeof isa Method ? JuliaInterpreter.compute_corrected_linerange(curr_scopeof) : nothing

    push!(debug_session.varrefs, VariableReference(:scope, curr_fr))
    local_var_ref_id = length(debug_session.varrefs)

    push!(debug_session.varrefs, VariableReference(:scope_globals, curr_fr))
    global_var_ref_id = length(debug_session.varrefs)

    scopes = []

    if isfile(file_name) && code_range !== nothing
        push!(scopes, Scope(name = "Local", variablesReference = local_var_ref_id, expensive = false, source = Source(name = basename(file_name), path = file_name), line = code_range.start, endLine = code_range.stop))
        push!(scopes, Scope(name = "Global", variablesReference = global_var_ref_id, expensive = false, source = Source(name = basename(file_name), path = file_name), line = code_range.start, endLine = code_range.stop))
    else
        push!(scopes, Scope(name = "Local", variablesReference = local_var_ref_id, expensive = false))
        push!(scopes, Scope(name = "Global", variablesReference = global_var_ref_id, expensive = false))
    end

    curr_mod = JuliaInterpreter.moduleof(curr_fr)
    push!(debug_session.varrefs, VariableReference(:module, curr_mod))

    push!(scopes, Scope(name = "Global ($(curr_mod))", variablesReference = length(debug_session.varrefs), expensive = true))

    return ScopesResponseArguments(scopes)
end

function source_request(debug_session::DebugSession, params::SourceArguments)
    @debug "getsource_request"

    source_id = params.source.sourceReference

    code = DebugEngines.get_source(debug_session.debug_engine, source_id)

    return SourceResponseArguments(code, missing)
end

"""
    error_message(err; limit = 200) -> String

`err` rendered for display in a response. The errors the debugger catches while rendering
came out of the debuggee's own code, so `showerror` can itself throw and needs its own
fallback — and so can printing the type it falls back to.
"""
function error_message(err; limit = 200)
    try
        return Base.invokelatest(sprintlimited, err, func = showerror, limit = limit)
    catch
        try
            return Base.invokelatest(sprintlimited, typeof(err), limit = limit)
        catch
            return "an error that could not be displayed"
        end
    end
end

"""
    safe_show(value) -> String

`sprintlimited(value)` that reports rather than throws. Everything a `variables` response
renders comes out of user objects, whose `show` — including `show(::IO, ::Type{…})` — can
throw, and that must not cost the client its response. The DAP `Variable` has no field for
"this failed", so the reason goes into the value the user reads.
"""
function safe_show(value)
    try
        return Base.invokelatest(sprintlimited, value)
    catch err
        return string("#error: ", error_message(err))
    end
end

construct_error_msg_for_var(name, value) =
    Variable(name = name, value = value, type = "", variablesReference = 0)

"""
    with_error_placeholder(f, name) -> Variable

Run `f`, which builds the `Variable` for one entry of a variables response and therefore
calls into user code, and substitute a placeholder carrying the reason if it throws: one
unrenderable entry must not cost the client the rest of the list.
"""
function with_error_placeholder(f, name)
    try
        return f()
    catch err
        return construct_error_msg_for_var(name, string("#error: ", error_message(err)))
    end
end

function construct_return_msg_for_var(debug_session::DebugSession, name, value)
    v_type = typeof(value)
    v_value_as_string = safe_show(value)

    if (isstructtype(v_type) || value isa AbstractArray || value isa AbstractDict) && !(value isa String || value isa Symbol)
        push!(debug_session.varrefs, VariableReference(:var, value))
        new_var_id = length(debug_session.varrefs)

        named_count = try
            if value isa Array || value isa Tuple
                0
            elseif value isa AbstractArray || value isa AbstractDict
                fieldcount(v_type) > 0 ? 1 : 0
            else
                fieldcount(v_type)
            end
        catch
            0
        end

        indexed_count = zero(Int64)

        if value isa AbstractArray || value isa AbstractDict || value isa Tuple
            try
                indexed_count = Int64(Base.invokelatest(length, value))
            catch err
            end
        end

        return Variable(
            name = name,
            value = v_value_as_string,
            type = safe_show(v_type),
            variablesReference = new_var_id,
            namedVariables = named_count,
            indexedVariables = indexed_count
        )
    else
        return Variable(name = name, value = v_value_as_string, type = safe_show(v_type), variablesReference = 0)
    end
end

function construct_return_msg_for_var_with_undef_value(debug_session::DebugSession, name)
    v_type_as_string = ""

    return Variable(name = name, type = v_type_as_string, value = "#undef", variablesReference = 0)
end

function push_field_variables!(variables, debug_session::DebugSession, value, skip_count, take_count)
    container_type = typeof(value)

    for i in Iterators.take(Iterators.drop(1:fieldcount(container_type), skip_count), take_count)
        name = string(fieldname(container_type, i))
        push!(variables, with_error_placeholder(name) do
            isdefined(value, i) ?
                construct_return_msg_for_var(debug_session, name, getfield(value, i)) :
                construct_return_msg_for_var_with_undef_value(debug_session, name)
        end)
    end
end

function get_keys_with_drop_take(value, skip_count, take_count)
    collect(Iterators.take(Iterators.drop(keys(value), skip_count), take_count))
end

function get_cartesian_with_drop_take(value, skip_count, take_count)
    collect(Iterators.take(Iterators.drop(CartesianIndices(value), skip_count), take_count))
end

function collect_global_refs(frame::JuliaInterpreter.Frame)
    try
        m = JuliaInterpreter.scopeof(frame)
        m isa Method || return []

        func = frame.framedata.locals[1].value
        args = (Base.unwrap_unionall(m.sig).parameters[2:end]...,)

        ci = code_typed(func, args, optimize = false)[1][1]

        return collect_global_refs(ci)
    catch err
        @error err
        []
    end
end

function collect_global_refs(ci::Core.CodeInfo, refs = Set([]))
    for expr in ci.code
        collect_global_refs(expr, refs)
    end
    refs
end

function collect_global_refs(expr::Expr, refs = Set([]))
    args = Meta.isexpr(expr, :call) ? expr.args[2:end] : expr.args
    for arg in args
        collect_global_refs(arg, refs)
    end

    refs
end

collect_global_refs(expr, refs) = nothing
collect_global_refs(expr::GlobalRef, refs) = push!(refs, expr)

function push_module_names!(variables, debug_session, mod)
    for n in names(mod, all = true)
        !isdefined(mod, n) && continue
        Base.isdeprecated(mod, n) && continue

        x = getfield(mod, n)
        x === Main && continue

        s = string(n)
        startswith(s, "#") && continue

        push!(variables, with_error_placeholder(s) do
            construct_return_msg_for_var(debug_session, s, x)
        end)
    end
end

function get_variable_reference(debug_session::DebugSession, var_ref_id)
    if var_ref_id isa Integer && 1 <= var_ref_id <= length(debug_session.varrefs)
        return debug_session.varrefs[var_ref_id]
    end

    return nothing
end

function variables_request(debug_session::DebugSession, params::VariablesArguments)
    @debug "getvariables_request"

    var_ref_id = params.variablesReference

    filter_type = coalesce(params.filter, "")
    skip_count = coalesce(params.start, 0)
    take_count = coalesce(params.count, typemax(Int))

    variables = Variable[]

    var_ref = get_variable_reference(debug_session, var_ref_id)
    var_ref === nothing && return VariablesResponseArguments(variables)

    if var_ref.kind == :scope
        curr_fr = var_ref.value

        vars = JuliaInterpreter.locals(curr_fr)

        for v in vars
            # TODO Figure out why #self# is here in the first place
            # For now we don't report it to the client
            if !startswith(string(v.name), "#") && string(v.name) != ""
                name = string(v.name)
                push!(variables, with_error_placeholder(name) do
                    construct_return_msg_for_var(debug_session, name, v.value)
                end)
            end
        end

        if JuliaInterpreter.isexpr(JuliaInterpreter.pc_expr(curr_fr), :return)
            push!(variables, with_error_placeholder("Return Value") do
                construct_return_msg_for_var(debug_session, "Return Value", JuliaInterpreter.get_return(curr_fr))
            end)
        end
    elseif var_ref.kind == :scope_globals
        curr_fr = var_ref.value
        globals = collect_global_refs(curr_fr)

        for g in globals
            if isdefined(g.mod, g.name)
                name = string(g.name)
                push!(variables, with_error_placeholder(name) do
                    construct_return_msg_for_var(debug_session, name, getfield(g.mod, g.name))
                end)
            end
        end
    elseif var_ref.kind == :module
        push_module_names!(variables, debug_session, var_ref.value)
    elseif var_ref.kind == :var
        container_type = typeof(var_ref.value)

        if filter_type == "" || filter_type == "named"
            if (var_ref.value isa AbstractArray || var_ref.value isa AbstractDict) && !(var_ref.value isa Array) &&
                fieldcount(container_type) > 0
                push!(debug_session.varrefs, VariableReference(:fields, var_ref.value))
                new_var_id = length(debug_session.varrefs)
                named_count = fieldcount(container_type)

                push!(variables, Variable(
                    "Fields",
                    "",
                    "",
                    missing,
                    missing,
                    new_var_id,
                    named_count,
                    0,
                    missing
                ))
            elseif var_ref.value isa Module
                push_module_names!(variables, debug_session, var_ref.value)
            else
                push_field_variables!(variables, debug_session, var_ref.value, skip_count, take_count)
            end
        end

        if (filter_type == "" || filter_type == "indexed")
            # Enumerating the container (`size`, `axes`, `keys`, `iterate`) is user code too;
            # if that fails nothing can be listed, so say so — and why. Entries pushed before
            # the failure are kept.
            try
                if var_ref.value isa Tuple
                    for i in Iterators.take(Iterators.drop(1:length(var_ref.value), skip_count), take_count)
                        name = string(i)
                        push!(variables, with_error_placeholder(name) do
                            construct_return_msg_for_var(debug_session, name, var_ref.value[i])
                        end)
                    end
                elseif var_ref.value isa AbstractArray
                    for i in Base.invokelatest(get_cartesian_with_drop_take, var_ref.value, skip_count, take_count)
                        name = join(string.(i.I), ',')
                        push!(variables, with_error_placeholder(name) do
                            construct_return_msg_for_var(debug_session, name, Base.invokelatest(getindex, var_ref.value, i))
                        end)
                    end
                elseif var_ref.value isa AbstractDict
                    for i in Base.invokelatest(get_keys_with_drop_take, var_ref.value, skip_count, take_count)
                        name = safe_show(i)
                        push!(variables, with_error_placeholder(name) do
                            construct_return_msg_for_var(debug_session, name, Base.invokelatest(getindex, var_ref.value, i))
                        end)
                    end
                end
            catch err
                push!(variables, construct_error_msg_for_var(
                    "#error",
                    string("This type doesn't implement the expected interface: ", error_message(err))
                ))
            end
        end
    elseif var_ref.kind == :fields
        if filter_type == "" || filter_type == "named"
            push_field_variables!(variables, debug_session, var_ref.value, skip_count, take_count)
        end
    end

    return VariablesResponseArguments(variables)
end

function set_variable_request(debug_session::DebugSession, params::SetVariableArguments)
    varref_id = params.variablesReference
    var_name = params.name
    var_value = params.value

    val_parsed = try
        parsed = Meta.parse(var_value)

        if parsed isa Expr && !(parsed.head == :call || parsed.head == :vect || parsed.head == :tuple)
            return DAPError("Only values or function calls are allowed.")
        end

        parsed
    catch err
        return DAPError(string("Something went wrong in the eval: ", sprint(showerror, err)))
    end

    var_ref = get_variable_reference(debug_session, varref_id)
    var_ref === nothing && return DAPError("Variable reference is no longer valid.")

    if var_ref.kind == :scope
        try
            ret = JuliaInterpreter.eval_code(var_ref.value, "$var_name = $var_value");

            s = construct_return_msg_for_var(debug_session::DebugSession, "", ret)

            return SetVariableResponseArguments(s.value, s.type, s.variablesReference, s.namedVariables, s.indexedVariables)
        catch err
            return DAPError(string("Something went wrong while setting the variable: ", sprint(showerror, err)))
        end
    elseif var_ref.kind == :var
        if isnumeric(var_name[1])
            try
                new_val = try
                    Core.eval(Main, val_parsed)
                catch err
                    return DAPError(string("Expression could not be evaluated: ", sprint(showerror, err)))
                end

                idx = Core.eval(Main, Meta.parse("($var_name)"))

                setindex!(var_ref.value, new_val, idx...)

                s = construct_return_msg_for_var(debug_session::DebugSession, "", new_val)

                return SetVariableResponseArguments(s.value, s.type, s.variablesReference, s.namedVariables, s.indexedVariables)
            catch err
                return DAPError("Something went wrong while setting the variable: $err")
            end
        else
            if Base.isimmutable(var_ref.value)
                return DAPError("Cannot change the fields of an immutable struct.")
            else
                try
                    new_val = try
                        Core.eval(Main, val_parsed)
                    catch err
                        return DAPError(string("Expression could not be evaluated: ", sprint(showerror, err)))
                    end

                    setfield!(var_ref.value, Symbol(var_name), new_val)

                    s = construct_return_msg_for_var(debug_session::DebugSession, "", new_val)

                    return SetVariableResponseArguments(s.value, s.type, s.variablesReference, s.namedVariables, s.indexedVariables)
                catch err
                    return DAPError(string("Something went wrong while setting the variable: ", sprint(showerror, err)))
                end
            end
        end
    elseif var_ref.kind == :scope_globals || var_ref.kind == :module
        mod = if var_ref.value isa JuliaInterpreter.Frame
            JuliaInterpreter.moduleof(var_ref.value)
        elseif var_ref.value isa Module
            var_ref.value
        else
            return DAPError("No module attached to this global variable.")
        end

        if !(mod isa Module)
            return DAPError("Can't determine the module this variable is defined in.")
        end

        new_val = try
            mod.eval(Meta.parse("$var_name = $var_value"))
        catch err
            return DAPError(string("Something went wrong while setting the variable: ", sprint(showerror, err)))
        end
        s = construct_return_msg_for_var(debug_session::DebugSession, "", new_val)

        return SetVariableResponseArguments(s.value, s.type, s.variablesReference, s.namedVariables, s.indexedVariables)
    else
        return DAPError("Unknown variable ref type.")
    end
end

function restart_frame_request(debug_session::DebugSession, params::RestartFrameArguments)
    debug_engine = debug_session.debug_engine
    frame_id = params.frameId

    if frame_id < 1 || debug_engine.frame === nothing
        return DAPError("Invalid frameId.")
    end

    curr_fr = JuliaInterpreter.leaf(debug_engine.frame)

    i = 1

    while frame_id > i
        if curr_fr.caller === nothing
            return DAPError("Invalid frameId.")
        end
        curr_fr = curr_fr.caller
        i += 1
    end

    if curr_fr.caller === nothing
        # We are in the top level

        debug_engine.frame = DebugEngines.get_next_top_level_frame(debug_engine)
    else
        curr_fr.pc = 1
        curr_fr.assignment_counter = 1
        curr_fr.callee = nothing

        debug_engine.frame = curr_fr
    end

    put!(debug_engine.next_cmd, (cmd = :continue,))

    return RestartFrameResponseResponseArguments()
end

function exception_info_request(debug_session::DebugSession, params::ExceptionInfoArguments)
    # This request fires on every uncaught-exception stop, and both the id and the
    # description are rendered from the debuggee's own exception object.
    last_exception = debug_session.debug_engine.last_exception
    exception_id = safe_show(typeof(last_exception))
    exception_description = error_message(last_exception, limit = 100_000)

    exception_stacktrace = try
        Base.invokelatest(sprint, Base.show_backtrace, debug_session.debug_engine.frame)
    catch err
        string("Error while printing the backtrace: ", error_message(err))
    end

    return ExceptionInfoResponseArguments(exception_id, exception_description, "userUnhandled", ExceptionDetails(missing, missing, missing, missing, exception_stacktrace, missing))
end

function evaluate_request(debug_session::DebugSession, params::EvaluateArguments)
    @debug "evaluate_request"

    if ismissing(params.frameId)
        return EvaluateResponseArguments("Error: received evaluate request without a frameId, this shouldn't happen for the Julia debugger.", missing, missing, 0, missing, missing, missing)
    end

    curr_fr = debug_session.debug_engine.frame
    curr_i = 1

    while params.frameId > curr_i
        if curr_fr.caller !== nothing
            curr_fr = curr_fr.caller
            curr_i += 1
        else
            break
        end
    end

    try
        ret_val = JuliaInterpreter.eval_code(curr_fr, params.expression)

        return EvaluateResponseArguments(Base.invokelatest(sprintlimited, ret_val), missing, missing, 0, missing, missing, missing)
    catch err
        @debug "error showing value" exception=(err, catch_backtrace())
        return EvaluateResponseArguments(string("Internal Error: ", sprint(showerror, err)), missing, missing, 0, missing, missing, missing)
    end
end

function continue_request(debug_session::DebugSession, params::ContinueArguments)
    @debug "continue_request"

    DebugEngines.execution_continue(debug_session.debug_engine)

    return ContinueResponseArguments(true)
end

function next_request(debug_session::DebugSession, params::NextArguments)
    @debug "next_request"

    DebugEngines.execution_next(debug_session.debug_engine)

    return NextResponseArguments()
end

function setp_in_request(debug_session::DebugSession, params::StepInArguments)
    @debug "stepin_request"

    DebugEngines.execution_step_in(debug_session.debug_engine, params.targetId)

    return StepInResponseArguments()
end

function step_in_targets_request(debug_session::DebugSession, params::StepInTargetsArguments)
    @debug "stepin_targets_request"

    targets = calls_on_line(debug_session)

    return StepInTargetsResponseArguments([
        StepInTarget(pc, string(expr)) for (pc, expr) in targets
    ])
end

function setp_out_request(debug_session::DebugSession, params::StepOutArguments)
    @debug "stepout_request"

    DebugEngines.execution_step_out(debug_session.debug_engine)

    return StepOutResponseArguments()
end

function disconnect_request(debug_session::DebugSession, params::DisconnectArguments)
    @debug "disconnect_request"

    if debug_session.debug_engine!==nothing
        DebugEngines.terminate(debug_session.debug_engine)
    end

    put!(debug_session.next_cmd, (cmd = :terminate,))

    return DisconnectResponseArguments()
end

function terminate_request(debug_session::DebugSession, params::TerminateArguments)
    @debug "terminate_request"

    if debug_session.debug_engine!==nothing
        DebugEngines.execution_terminate(debug_session.debug_engine)
    end

    return TerminateResponseArguments()
end

function threads_request(debug_session::DebugSession, params::Nothing)
    return ThreadsResponseArguments([Thread(id = 1, name = "Main Thread")])
end

function breakpointlocations_request(debug_session::DebugSession, params::BreakpointLocationsArguments)
    return BreakpointLocationsResponseArguments(BreakpointLocation[])
end
