# Request handlers

function run_notification(conn, state::DebuggerState, params::String)
    @debug "run_request"

    state.debug_mode = :launch

    put!(state.next_cmd, (cmd = :run, program = params))
end

function debug_notification(conn, state::DebuggerState, params::DebugArguments)
    @debug "debug_request"

    state.debug_mode = :launch

    filename_to_debug = params.program

    @debug "We are debugging the file $filename_to_debug."

    task_local_storage()[:SOURCE_PATH] = filename_to_debug

    ex = _parse_julia_file(filename_to_debug)

    # Empty file case
    if ex === nothing
        JSONRPC.send(conn, finished_notification_type, nothing)
        put!(state.next_cmd, (cmd = :stop,))
        return
    end

    state.top_level_expressions, _ = JuliaInterpreter.split_expressions(Main, ex)
    state.current_top_level_expression = 0

    state.frame = get_next_top_level_frame(state)

    if params.stopOnEntry
        JSONRPC.send(conn, stopped_notification_type, StoppedEventArguments("entry", missing, 1, missing, missing, missing))
    elseif JuliaInterpreter.shouldbreak(state.frame, state.frame.pc)
        JSONRPC.send(conn, stopped_notification_type, StoppedEventArguments("breakpoint", missing, 1, missing, missing, missing))
    else
        put!(state.next_cmd, (cmd = :continue,))
    end
end

function exec_notification(conn, state::DebuggerState, params::ExecArguments)
    @debug "exec_request"

    state.debug_mode = :attach

    state.sources[0] = params.code

    ex = Meta.parse(params.code)

    state.top_level_expressions, _ = JuliaInterpreter.split_expressions(Main, ex)
    state.current_top_level_expression = 0

    state.frame = get_next_top_level_frame(state)

    if params.stopOnEntry
        JSONRPC.send(conn, stopped_notification_type, StoppedEventArguments("entry", missing, 1, missing, missing, missing))
    elseif JuliaInterpreter.shouldbreak(state.frame, state.frame.pc)
        JSONRPC.send(conn, stopped_notification_type, StoppedEventArguments("breakpoint", missing, 1, missing, missing, missing))
    else
        put!(state.next_cmd, (cmd = :continue,))
    end
end

function set_break_points_request(conn, state::DebuggerState, params::SetBreakpointsArguments)
    @debug "setbreakpoints_request"

    file = params.source.path

    for bp in JuliaInterpreter.breakpoints()
        if bp isa JuliaInterpreter.BreakpointFileLocation
            if bp.path == file
                JuliaInterpreter.remove(bp)
            end
        end
    end

    for bp in params.breakpoints
        @debug "Setting one breakpoint at line $(bp.line) with condition $(bp.condition) in file $file."

        JuliaInterpreter.breakpoint(file, bp.line, bp.condition)
    end

    res = SetBreakpointsResponseArguments([Breakpoint(true) for i = 1:length(params.breakpoints)])
end

function set_exception_break_points_request(conn, state::DebuggerState, params::SetExceptionBreakpointsArguments)
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

    if "compilemode" in opts
        state.compile_mode = JuliaInterpreter.Compiled()
    else
        state.compile_mode = JuliaInterpreter.finish_and_return!
    end

    return SetExceptionBreakpointsResponseArguments(String[], missing)
end

function set_function_break_points_request(conn, state::DebuggerState, params::SetFunctionBreakpointsArguments)
    @debug "setfunctionbreakpoints_request"

    bps = map(params.breakpoints) do i
        decoded_name = i.name
        decoded_condition = i.condition

        parsed_condition = try
            decoded_condition == "" ? nothing : Meta.parse(decoded_condition)
        catch err
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

                            return (mod = Main, name = parsed_name.args[1], signature = map(j->j.args[1], parsed_name.args[2:end]), condition = parsed_condition)
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

    bps = filter(i->i !== nothing, bps)

    for bp in JuliaInterpreter.breakpoints()
        if bp isa JuliaInterpreter.BreakpointSignature
            JuliaInterpreter.remove(bp)
        end
    end

    state.not_yet_set_function_breakpoints = Set{Any}(bps)

    attempt_to_set_f_breakpoints!(state.not_yet_set_function_breakpoints)

    return SetFunctionBreakpointsResponseArguments([Breakpoint(true) for i = 1:length(bps)])
end

function stack_trace_request(conn, state::DebuggerState, params::StackTraceArguments)
    @debug "getstacktrace_request"

    fr = state.frame

    curr_fr = JuliaInterpreter.leaf(fr)

    frames_as_string = String[]

    frames = StackFrame[]

    id = 1
    while curr_fr !== nothing
        curr_scopeof = JuliaInterpreter.scopeof(curr_fr)
        curr_whereis = JuliaInterpreter.whereis(curr_fr)

        file_name = curr_whereis[1]
        lineno = curr_whereis[2]
        meth_or_mod_name = Base.nameof(curr_fr)

        # Is this a file from base?
        if !isabspath(file_name)
            file_name = basepath(file_name)
        end

        if isfile(file_name)
            push!(
                frames,
                StackFrame(
                    id,
                    meth_or_mod_name,
                    Source(
                        basename(file_name),
                        file_name,
                        missing,
                        missing,
                        "julia-adapter-data",
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
        elseif curr_scopeof isa Method
            ret = JuliaInterpreter.CodeTracking.definition(String, curr_fr.framecode.scope)
            if ret !== nothing
                state.sources[state.next_source_id], loc = ret
                push!(
                    frames,
                    StackFrame(
                        id,
                        meth_or_mod_name,
                        Source(
                            file_name,
                            missing,
                            state.next_source_id,
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
                state.next_source_id += 1
            else
                src = curr_fr.framecode.src
                src = JuliaInterpreter.copy_codeinfo(src)
                JuliaInterpreter.replace_coretypes!(src; rev=true)
                code = Base.invokelatest(JuliaInterpreter.framecode_lines, src)

                state.sources[state.next_source_id] = join(code, '\n')

                push!(
                    frames,
                    StackFrame(
                        id,
                        meth_or_mod_name,
                        Source(
                            file_name,
                            missing,
                            state.next_source_id,
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
                state.next_source_id += 1
            end
        else
            # For now we are assuming that this can only happen
            # for code that is passed via the @enter or @run macros,
            # and that code we have stored as source with id 0
            push!(
                    frames,
                    StackFrame(
                        id,
                        meth_or_mod_name,
                        Source(
                            "REPL",
                            missing,
                            0,
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
        end

        id += 1
        curr_fr = curr_fr.caller
    end

    return StackTraceResponseArguments(frames, length(frames))
end

function scopes_request(conn, state::DebuggerState, params::ScopesArguments)
    @debug "getscope_request"

    curr_fr = JuliaInterpreter.leaf(state.frame)

    i = 1

    while params.frameId > i
        curr_fr = curr_fr.caller
        i += 1
    end

    curr_scopeof = JuliaInterpreter.scopeof(curr_fr)
    curr_whereis = JuliaInterpreter.whereis(curr_fr)

    file_name = curr_whereis[1]
    code_range = curr_scopeof isa Method ? JuliaInterpreter.compute_corrected_linerange(curr_scopeof) : nothing

    push!(state.varrefs, VariableReference(:scope, curr_fr))

    var_ref_id = length(state.varrefs)

    if isfile(file_name) && code_range !== nothing
        return ScopesResponseArguments([Scope("Local", missing, var_ref_id, missing, missing, false, Source(basename(file_name), file_name, missing, missing, missing, missing, missing, missing), code_range.start, missing, code_range.stop, missing)])
    else
        return ScopesResponseArguments([Scope("Local", var_ref_id, false)])
    end
end

function source_request(conn, state::DebuggerState, params::SourceArguments)
    @debug "getsource_request"

    source_id = params.source.sourceReference

    return SourceResponseArguments(state.sources[source_id], missing)
end

function construct_return_msg_for_var(state::DebuggerState, name, value)
    v_type = typeof(value)
    v_type_as_string = string(v_type)
    v_value_as_string = Base.invokelatest(repr, value)

    if (isstructtype(v_type) || value isa AbstractArray || value isa AbstractDict) && !(value isa String || value isa Symbol)
        push!(state.varrefs, VariableReference(:var, value))
        new_var_id = length(state.varrefs)

        named_count = if value isa Array || value isa Tuple
            0
        elseif value isa AbstractArray || value isa AbstractDict
            fieldcount(v_type) > 0 ? 1 : 0
        else
            fieldcount(v_type)
        end

        indexed_count = 0

        if value isa AbstractArray || value isa AbstractDict || value isa Tuple
            try
                indexed_count = Base.invokelatest(length, value)
            catch err
            end
        end

        return Variable(
            name,
            v_value_as_string,
            v_type_as_string,
            missing,
            missing,
            new_var_id,
            named_count,
            indexed_count,
            missing
        )
    else
        return Variable(
            name,
            v_value_as_string,
            v_type_as_string,
            missing,
            missing,
            0,
            0,
            0,
            missing
        )
    end
end

function construct_return_msg_for_var_with_undef_value(state::DebuggerState, name)
    v_type_as_string = ""
    v_value_encoded = Base64.base64encode("#undef")

    return string("0;", name, ";", v_type_as_string, ";0;0;", v_value_encoded)
end

function get_keys_with_drop_take(value, skip_count, take_count)
    collect(Iterators.take(Iterators.drop(keys(value), skip_count), take_count))
end

function get_cartesian_with_drop_take(value, skip_count, take_count)
    collect(Iterators.take(Iterators.drop(CartesianIndices(value), skip_count), take_count))
end

function variables_request(conn, state::DebuggerState, params::VariablesArguments)
    @debug "getvariables_request"

    var_ref_id = params.variablesReference

    filter_type = something(params.filter, "")
    skip_count = something(params.start, 0)
    take_count = something(params.count, typemax(Int))

    var_ref = state.varrefs[var_ref_id]

    variables = Variable[]

    # struct Variable
    #     name::String
    #     value::String
    #     type::Union{Nothing,String}
    #     presentatonHint::Union{Nothing,VariablePresentationHint}
    #     evaluateName::Union{Nothing,String}
    #     variablesReference::Int
    #     namedVariables::Union{Nothing,Int}
    #     indexedVariables::Union{Nothing,Int}
    #     memoryReference::Union{Nothing,String}
    # end

    if var_ref.kind == :scope
        curr_fr = var_ref.value

        vars = JuliaInterpreter.locals(curr_fr)

        for v in vars
            # TODO Figure out why #self# is here in the first place
            # For now we don't report it to the client
            if !startswith(string(v.name), "#") && string(v.name) != ""
                push!(variables, construct_return_msg_for_var(state, string(v.name), v.value))
            end
        end

        if JuliaInterpreter.isexpr(JuliaInterpreter.pc_expr(curr_fr), :return)
            ret_val = JuliaInterpreter.get_return(curr_fr)
            push!(variables, construct_return_msg_for_var(state, "Return Value", ret_val))
        end
    elseif var_ref.kind == :var
        container_type = typeof(var_ref.value)

        if filter_type == "" || filter_type == "named"
            if (var_ref.value isa AbstractArray || var_ref.value isa AbstractDict) && !(var_ref.value isa Array) &&
                fieldcount(container_type) > 0
                push!(state.varrefs, VariableReference(:fields, var_ref.value))
                new_var_id = length(state.varrefs)
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
            else
                for i = Iterators.take(Iterators.drop(1:fieldcount(container_type), skip_count), take_count)
                    s = isdefined(var_ref.value, i) ?
                        construct_return_msg_for_var(state, string(fieldname(container_type, i)), getfield(var_ref.value, i)) :
                        construct_return_msg_for_var_with_undef_value(state, string(fieldname(container_type, i)))
                    push!(variables, s)
                end
            end
        end

        if (filter_type == "" || filter_type == "indexed")
            if var_ref.value isa Tuple
                for i in Iterators.take(Iterators.drop(1:length(var_ref.value), skip_count), take_count)
                    s = construct_return_msg_for_var(state, join(string.(i), ','), var_ref.value[i])
                    push!(variables, s)
                end
            elseif var_ref.value isa AbstractArray
                for i in Base.invokelatest(get_cartesian_with_drop_take, var_ref.value, skip_count, take_count)
                    s = ""
                    try
                        val = Base.invokelatest(getindex, var_ref.value, i)
                        s = construct_return_msg_for_var(state, join(string.(i.I), ','), val)
                    catch err
                        s = string("0;", join(string.(i.I), ','), ";;0;0;", Base64.base64encode("#error"))
                    end
                    push!(variables, s)
                end
            elseif var_ref.value isa AbstractDict
                for i in Base.invokelatest(get_keys_with_drop_take, var_ref.value, skip_count, take_count)
                    key_as_string = Base.invokelatest(repr, i)
                    s = ""
                    try
                        val = Base.invokelatest(getindex, var_ref.value, i)
                        s = construct_return_msg_for_var(state, key_as_string, val)
                    catch err
                        s = Variable(
                            join(string.(i.I), ','),
                            "#error",
                            "",
                            missing,
                            missing,
                            0,
                            0,
                            0,
                            missing
                        )
                    end
                    push!(variables, s)
                end
            end
        end
    elseif var_ref.kind == :fields
        container_type = typeof(var_ref.value)

        if filter_type == "" || filter_type == "named"
            for i = Iterators.take(Iterators.drop(1:fieldcount(container_type), skip_count), take_count)
                s = isdefined(var_ref.value, i) ?
                    construct_return_msg_for_var(state, string(fieldname(container_type, i)), getfield(var_ref.value, i)) :
                    construct_return_msg_for_var_with_undef_value(state, string(fieldname(container_type, i)))
                push!(variables, s)
            end
        end

    end

    return variables
end

function set_variable_request(conn, state::DebuggerState, params::SetVariableArguments)
    varref_id = params.variablesReference
    var_name = params.name
    var_value = params.value

    val_parsed = try
        parsed = Meta.parse(var_value)

        if parsed isa Expr && !(parsed.head == :call || parsed.head == :vect || parsed.head == :tuple)
            return JSONRPC.JSONRPCError(-32600, "Only values or function calls are allowed.", nothing)
        end

        parsed
    catch err
        return JSONRPC.JSONRPCError(-32600, "Something went wrong in the eval.", nothing)
    end

    var_ref = state.varrefs[varref_id]

    if var_ref.kind == :scope
        try
            ret = JuliaInterpreter.eval_code(var_ref.value, "$var_name = $var_value");

            s = construct_return_msg_for_var(state::DebuggerState, "", ret)

            return SetVariableResponseArguments(s.value, s.type, s.variablesReference, s.namedVariables, s.indexedVariables)
        catch err
            return JSONRPC.JSONRPCError(-32600, "Something went wrong in the set: $err", nothing)
        end
    elseif var_ref.kind == :var
        if isnumeric(var_name[1])
            try
                new_val = try
                    Core.eval(Main, val_parsed)
                catch err
                    return JSONRPC.JSONRPCError(-32600, "Expression cannot be evaluated.", nothing)
                end

                idx = Core.eval(Main, Meta.parse("($var_name)"))

                setindex!(var_ref.value, new_val, idx...)

                s = construct_return_msg_for_var(state::DebuggerState, "", new_val)

                return SetVariableResponseArguments(s.value, s.type, s.variablesReference, s.namedVariables, s.indexedVariables)
            catch err
                return JSONRPC.JSONRPCError(-32600, "Something went wrong in the set: $err", nothing)
            end
        else
            if Base.isimmutable(var_ref.value)
                return JSONRPC.JSONRPCError(-32600, "Cannot change the fields of an immutable struct.", nothing)
            else
                try
                    new_val = try
                        Core.eval(Main, val_parsed)
                    catch err
                        return JSONRPC.JSONRPCError(-32600, "Expression cannot be evaluated.", nothing)
                    end

                    setfield!(var_ref.value, Symbol(var_name), new_val)

                    s = construct_return_msg_for_var(state::DebuggerState, "", new_val)

                    return SetVariableResponseArguments(s.value, s.type, s.variablesReference, s.namedVariables, s.indexedVariables)
                catch err
                    return JSONRPC.JSONRPCError(-32600, "Something went wrong in the set: $err", nothing)
                end
            end
        end
    else
        error("Unknown var ref type.")
    end
end

# TODO CHANGE TO NOTIFICATION
function restart_frame_request(conn, state::DebuggerState, params::RestartFrameArguments)
    frame_id = params.frameId

    curr_fr = JuliaInterpreter.leaf(state.frame)

    i = 1

    while frame_id > i
        curr_fr = curr_fr.caller
        i += 1
    end

    if curr_fr.caller === nothing
        # We are in the top level

        state.current_top_level_expression = 0

        state.frame = get_next_top_level_frame(state)
    else
        curr_fr.pc = 1
        curr_fr.assignment_counter = 1
        curr_fr.callee = nothing

        state.frame = curr_fr
    end

    put!(state.next_cmd, (cmd = :continue,))

    return
end

function exception_info_request(conn, state::DebuggerState, params::ExceptionInfoArguments)
    exception_id = string(typeof(state.last_exception))
    exception_description = sprint(Base.showerror, state.last_exception)

    exception_stacktrace = sprint(Base.show_backtrace, state.frame)

    return ExceptionInfoResponseArguments(exception_id, exception_description, "userUnhandled", ExceptionDetails(missing, missing, missing, missing, exception_stacktrace, missing))
end

function evaluate_request(conn, state::DebuggerState, params::EvaluateArguments)
    @debug "evaluate_request"

    curr_fr = state.frame
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

        return EvaluateResponseArguments(Base.invokelatest(repr, ret_val), missing, missing, 0, missing, missing, missing)
    catch err
        return EvaluateResponseArguments("#error", missing, missing, 0, missing, missing, missing)
    end
end

# TODO Change to notification
function continue_request(conn, state::DebuggerState, params::ContinueArguments)
    @debug "continue_request"

    put!(state.next_cmd, (cmd = :continue,))

    return
end

function next_request(conn, state::DebuggerState, params::NextArguments)
    @debug "next_request"

    put!(state.next_cmd, (cmd = :next,))

    return
end

function setp_in_request(conn, state::DebuggerState, params::StepInArguments)
    @debug "stepin_request"

    put!(state.next_cmd, (cmd = :stepIn,))

    return
end

function setp_out_request(conn, state::DebuggerState, params::StepOutArguments)
    @debug "stepout_request"

    put!(state.next_cmd, (cmd = :stepOut,))

    return
end

function disconnect_request(conn, state::DebuggerState, params::DisconnectArguments)
    @debug "disconnect_request"

    put!(state.next_cmd, (cmd = :stop,))

    return
end

function terminate_request(conn, state::DebuggerState, params::TerminateArguments)
    @debug "terminate_request"

    JSONRPC.send(conn, finished_notification_type, nothing)
    put!(state.next_cmd, (cmd = :stop,))

    return
end
