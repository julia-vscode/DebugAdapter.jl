module DebugEngines

import ..JuliaInterpreter

mutable struct DebugEngine
    mod::Module
    code::String
    filename::String
    stop_on_entry::Bool

    next_cmd::Channel{Any}

    frame::Union{Nothing, JuliaInterpreter.Frame}

    expr_splitter::Union{JuliaInterpreter.ExprSplitter,Nothing}

    compile_mode
    not_yet_set_compiled_items::Vector{String}

    not_yet_set_function_breakpoints::Set{Any}

    last_exception

    on_stop::Function

    sources::Vector{String}
    source_id_by_name::Dict{String,Int}

    function DebugEngine(mod::Module, code::String, filename::String, stop_on_entry::Bool, on_stop::Function)
        return new(
            mod,
            code,
            filename,
            stop_on_entry,

            Channel{Any}(Inf),
            nothing,
            nothing,

            isdefined(JuliaInterpreter, :RecursiveInterpreter) ?
                JuliaInterpreter.RecursiveInterpreter() :
                JuliaInterpreter.finish_and_return!,
            String[],
            Set{Any}(),
            nothing,
            on_stop,
            String[],
            Dict{String,Int}()
        )
    end
end

function get_obj_by_accessor(accessor, super = nothing)
    parts = split(accessor, '.')
    @assert length(parts) > 0
    top = popfirst!(parts)
    if super === nothing
        # try getting module from loaded_modules_array first and then from Main:
        loaded_modules = Base.loaded_modules_array()
        ind = findfirst(==(top), string.(loaded_modules))
        if ind !== nothing
            root = loaded_modules[ind]
            if length(parts) > 0
                return get_obj_by_accessor(join(parts, '.'), root)
            end
            return root
        else
            return get_obj_by_accessor(accessor, Main)
        end
    else
        if isdefined(super, Symbol(top))
            this = getfield(super, Symbol(top))
            if length(parts) > 0
                if this isa Module
                    return get_obj_by_accessor(join(parts, '.'), this)
                end
            else
                return this
            end
        end
    end
    return nothing
end

function toggle_mode_for_all_submodules(mod, compiled, seen = Set())
    for name in names(mod; all = true)
        # it's ok to ignore deprecated bindings here since they are very unlikely
        # to be a module
        if isdefined(mod, name) && !Base.isdeprecated(mod, name)
            obj = getfield(mod, name)
            if obj !== mod && obj isa Module && !(obj in seen)
                push!(seen, obj)
                if compiled
                    push!(JuliaInterpreter.compiled_modules, obj)
                else
                    delete!(JuliaInterpreter.compiled_modules, obj)
                end
                toggle_mode_for_all_submodules(obj, compiled, seen)
            end
        end
    end
end

function reset_compiled_items()
    @debug "reset_compiled_items"
    # reset compiled modules/methods
    empty!(JuliaInterpreter.compiled_modules)
    empty!(JuliaInterpreter.compiled_methods)
    empty!(JuliaInterpreter.interpreted_methods)
    JuliaInterpreter.set_compiled_methods()
    JuliaInterpreter.clear_caches()
end

function set_compiled_functions_modules!(debug_engine::DebugEngine, items::Vector{String})
    @debug "set_compiled_functions_modules!"

    reset_compiled_items()
    apply_compiled_items!(debug_engine, items)
end

compiled_items_state() = (
    copy(JuliaInterpreter.compiled_modules),
    copy(JuliaInterpreter.compiled_methods),
    copy(JuliaInterpreter.interpreted_methods)
)

"""
Applies the compiled items that could not be applied yet, e.g. because the module
they name had not been loaded, on top of the current settings.

This runs every time the debuggee stops. Clearing JuliaInterpreter's caches drops
the framecodes of the paused frames from them, and with those the breakpoints the
client adds or removes while paused never reach the code that is executing
(#99). So the caches are only cleared when the retry actually changed something.
"""
function retry_compiled_items!(debug_engine::DebugEngine)
    before = compiled_items_state()
    apply_compiled_items!(debug_engine, debug_engine.not_yet_set_compiled_items)
    if compiled_items_state() != before
        @debug "compiled items changed, clearing caches"
        JuliaInterpreter.clear_caches()
    end
end

function apply_compiled_items!(debug_engine::DebugEngine, items::Vector{String})
    unset = String[]

    @debug "setting as compiled" items = items

    # sort inputs once so that removed items are at the end
    sort!(items, lt = function (a, b)
        am = startswith(a, '-')
        bm = startswith(b, '-')

        return am == bm ? isless(a, b) : bm
    end)

    # user wants these compiled:
    for acc in items
        if acc == "ALL_MODULES_EXCEPT_MAIN"
            for mod in values(Base.loaded_modules)
                if mod != Main
                    @debug "setting $mod and submodules as compiled via ALL_MODULES_EXCEPT_MAIN"
                    push!(JuliaInterpreter.compiled_modules, mod)
                    toggle_mode_for_all_submodules(mod, true, Set([Main]))
                end
            end
            push!(unset, acc)
            continue
        end
        oacc = acc
        is_interpreted = startswith(acc, '-') && length(acc) > 1
        if is_interpreted
            acc = acc[2:end]
        end
        all_submodules = endswith(acc, '.')
        acc = strip(acc, '.')
        obj = get_obj_by_accessor(acc)

        if obj === nothing
            push!(unset, oacc)
            continue
        end

        if is_interpreted
            if obj isa Base.Callable
                try
                    for m in methods(Base.unwrap_unionall(obj))
                        push!(JuliaInterpreter.interpreted_methods, m)
                    end
                catch err
                    @warn "Setting $obj as an interpreted method failed."
                end
            elseif obj isa Module
                delete!(JuliaInterpreter.compiled_modules, obj)
                if all_submodules
                    toggle_mode_for_all_submodules(obj, false)
                end
                # need to push these into unset because of ALL_MODULES_EXCEPT_MAIN
                # being re-applied every time
                push!(unset, oacc)
            end
        else
            if obj isa Base.Callable
                try
                    for m in methods(Base.unwrap_unionall(obj))
                        push!(JuliaInterpreter.compiled_methods, m)
                    end
                catch err
                    @warn "Setting $obj as an interpreted method failed."
                end
            elseif obj isa Module
                push!(JuliaInterpreter.compiled_modules, obj)
                if all_submodules
                    toggle_mode_for_all_submodules(obj, true)
                end
            end
        end
    end

    @debug "remaining items" unset = unset
    debug_engine.not_yet_set_compiled_items = unset
end

function attempt_to_set_f_breakpoints!(bps)
    for bp in bps
        @debug "Trying to set function breakpoint for '$(bp.name)'."
        try
            f = Core.eval(bp.mod, bp.name)

            signat = if bp.signature !== nothing
                Tuple{(Core.eval(Main, i) for i in bp.signature)...}
            else
                nothing
            end

            JuliaInterpreter.breakpoint(f, signat, bp.condition)
            delete!(bps, bp)

            @debug "Setting function breakpoint for '$(bp.name)' succeeded."
        catch err
            @debug "Setting function breakpoint for '$(bp.name)' failed."
        end
    end
end

"""
The code being debugged cannot be run any further, because of the state of the
code itself rather than a defect in the debugger.

The session reports such an error in the debug console and ends the run the
way a finished debuggee does, instead of letting it reach the crash handler.
"""
abstract type UserCodeError <: Exception end

"""
The next top-level expression of the code being debugged could not be loaded:
expanding its macros or lowering it failed, or evaluating the declaration it
consists of did. `error` is what Julia threw, and is what `include` would have
shown the user.
"""
struct CodeLoadError <: UserCodeError
    filename::String
    error
end

function Base.showerror(io::IO, err::CodeLoadError)
    # The error can come from the user's own code, e.g. a macro, whose
    # `showerror` may be newer than the world this runs in, and may itself fail.
    message = try
        Base.invokelatest(sprint, showerror, err.error)
    catch
        "Error while displaying the original error."
    end
    print(io, "Debugging `", err.filename, "` stopped because its code could not be loaded:\n", message)
end

# Evaluates the user's code as it is, so whatever it throws is theirs.
function load_user_code(f, debug_engine)
    try
        return f()
    catch err
        throw(CodeLoadError(debug_engine.filename, err))
    end
end

function get_next_top_level_frame(state)
    state.expr_splitter === nothing && return nothing
    # Moving to the next expression creates the module of a `module` block.
    x = load_user_code(() -> iterate(state.expr_splitter), state)
    x === nothing && return nothing

    (mod, ex), _ = x
    if Meta.isexpr(ex, :global, 1)
        # global assignment can be lowered, but global declaration can't,
        # let's just evaluate and iterate to next
        load_user_code(() -> Core.eval(mod, ex), state)
        return get_next_top_level_frame(state)
    end
    return try
        JuliaInterpreter.Frame(mod, ex)
    catch err
        # Only a failure to lower the user's code is theirs; anything else from
        # building the frame is a defect in JuliaInterpreter or here, and has to
        # reach the crash handler. Lowering throws a `LoadError` when expanding a
        # macro fails (e.g. `L"..."` without LaTeXStrings), on every Julia
        # version. It returns a syntax error found during lowering instead, which
        # JuliaInterpreter up to 0.10 (still shipped for Julia < 1.10) turns into
        # exactly this `ArgumentError`; later versions defer it to when the
        # statement runs.
        if err isa LoadError ||
                (err isa ArgumentError && startswith(err.msg, "lowering returned an error"))
            throw(CodeLoadError(state.filename, err))
        end
        rethrow()
    end
end

function is_toplevel_return(frame)
    is_a_return_node = @static if isdefined(Core, :ReturnNode)
        JuliaInterpreter.pc_expr(frame) isa Core.ReturnNode
    else
        false
    end
    frame.framecode.scope isa Module && (JuliaInterpreter.isexpr(JuliaInterpreter.pc_expr(frame), :return) || is_a_return_node)
end

function our_debug_command(debug_engine::DebugEngine, cmd::Symbol)
    while true
        @debug "Running a new frame." debug_engine.frame debug_engine.compile_mode

        ret = Base.invokelatest(JuliaInterpreter.debug_command, debug_engine.compile_mode, debug_engine.frame, cmd, true)

        retry_compiled_items!(debug_engine)

        attempt_to_set_f_breakpoints!(debug_engine.not_yet_set_function_breakpoints)

        @debug "Finished running frame."

        if ret !== nothing && is_toplevel_return(ret[1])
            ret = nothing
        end

        if ret !== nothing
            debug_engine.frame = ret[1]
            return ret[2]
        end

        debug_engine.frame = get_next_top_level_frame(debug_engine)

        if debug_engine.frame === nothing
            return nothing
        end

        ret !== nothing && error("Invalid state.")

        if ret === nothing && (cmd == :n || cmd == :s || cmd == :finish || JuliaInterpreter.shouldbreak(debug_engine.frame, debug_engine.frame.pc))
            return debug_engine.frame.pc
        end
    end
end

# Public API

@enum StopReason begin
    StopReasonEntry
    StopReasonBreakpoint
    StopReasonException
    StopReasonStep
end

is_valid_expression(x) = true # atom
is_valid_expression(::Nothing) = false # empty
is_valid_expression(ex::Expr) = !Meta.isexpr(ex, (:incomplete, :error))

"""
The code handed to the debugger is not parseable Julia, so there is nothing to
step through.

That is the state of the user's file, not a defect in the debugger, which is
why it is a type of its own: the caller turns it into a message in the debug
console, where it used to escape as a bare `ErrorException("Invalid
expression")` and be filed as a crash.
"""
struct InvalidExpressionError <: UserCodeError
    filename::String
end

function Base.showerror(io::IO, err::InvalidExpressionError)
    print(io, "Cannot debug `", err.filename, "`: it is not valid Julia code.")
end

function Base.run(debug_engine::DebugEngine)
    # @debug "setting source_path" file = params.file
    task_local_storage()[:SOURCE_PATH] = debug_engine.filename

    ex = Base.parse_input_line(debug_engine.code; filename=debug_engine.filename)

    # An unparseable file (or one that is empty, or whose lowering failed) has
    # nothing to debug. The caller answers this with a message in the debug
    # console and ends the session.
    if !is_valid_expression(ex)
        throw(InvalidExpressionError(debug_engine.filename))
    end

    # Queueing the first expression creates the module of a `module` block.
    debug_engine.expr_splitter = load_user_code(() -> JuliaInterpreter.ExprSplitter(debug_engine.mod, ex), debug_engine) # TODO: line numbers ?
    debug_engine.frame = get_next_top_level_frame(debug_engine)

    if debug_engine.frame === nothing
        # Start "Debug" from Code Cell
        return
    end

    if debug_engine.stop_on_entry
        debug_engine.on_stop(StopReasonEntry)
    elseif JuliaInterpreter.shouldbreak(debug_engine.frame, debug_engine.frame.pc)
        debug_engine.on_stop(StopReasonBreakpoint)
    else
        put!(debug_engine.next_cmd, (cmd = :continue,))
    end


    while true
        msg = take!(debug_engine.next_cmd)

        ret = nothing

        if msg.cmd == :run

        elseif msg.cmd == :stop
            break
        else
            if msg.cmd == :continue
                ret = our_debug_command(debug_engine, :c)
            elseif msg.cmd == :next
                ret = our_debug_command(debug_engine, :n)
            elseif msg.cmd == :stepIn
                if msg.targetId === missing
                    ret = our_debug_command(debug_engine, :s)
                else
                    itr = 0
                    success = true
                    while debug_engine.frame.pc < msg.targetId
                        ret = our_debug_command(debug_engine, :nc)
                        if ret isa JuliaInterpreter.BreakpointRef
                            success = false
                            break
                        end
                        itr += 1
                        if itr > 100
                            success = false
                            @warn "Could not step into specified target."
                            break
                        end
                    end

                    if success
                        ret = our_debug_command(debug_engine, :s)
                    end
                end
            elseif msg.cmd == :stepOut
                ret = our_debug_command(debug_engine, :finish)
            end

            if ret === nothing
                # TODO IS THIS RIGHT???
                break
                # state.debug_mode == :launch && break
            else
                if ret isa JuliaInterpreter.BreakpointRef
                    if ret.err === nothing
                        debug_engine.on_stop(StopReasonBreakpoint)
                    else
                        debug_engine.last_exception = ret.err
                        error_msg = try
                            Base.invokelatest(sprint, Base.showerror, ret.err)
                        catch err
                            "Error while displaying the original error."
                        end
                        debug_engine.on_stop(StopReasonException, error_msg)
                    end
                elseif ret isa Number
                    debug_engine.on_stop(StopReasonStep)
                elseif ret === nothing
                    DebugEngine.on_stop(StopReasonStep)
                end
            end
        end
    end
end

function terminate(debug_engine::DebugEngine)
    put!(debug_engine.next_cmd, (cmd = :stop,))
end

function set_function_breakpoints!(debug_engine::DebugEngine, breakpoints)
    for bp in JuliaInterpreter.breakpoints()
        if bp isa JuliaInterpreter.BreakpointSignature
            JuliaInterpreter.remove(bp)
        end
    end

    debug_engine.not_yet_set_function_breakpoints = Set{Any}(breakpoints)

    attempt_to_set_f_breakpoints!(debug_engine.not_yet_set_function_breakpoints)
end

function set_compiled_mode!(debug_engine::DebugEngine, compiled_mode::Bool)
    if isdefined(JuliaInterpreter, :RecursiveInterpreter)
        if compiled_mode
            debug_engine.compile_mode = JuliaInterpreter.NonRecursiveInterpreter()
        else
            debug_engine.compile_mode = JuliaInterpreter.RecursiveInterpreter()
        end
    else
        if compiled_mode
            debug_engine.compile_mode = JuliaInterpreter.Compiled()
        else
            debug_engine.compile_mode = JuliaInterpreter.finish_and_return!
        end
    end
end

function execution_continue(debug_engine::DebugEngine)
    put!(debug_engine.next_cmd, (cmd = :continue,))
end

function execution_next(debug_engine::DebugEngine)
    put!(debug_engine.next_cmd, (cmd = :next,))
end

function execution_step_in(debug_engine::DebugEngine, target_id)
    put!(debug_engine.next_cmd, (cmd = :stepIn, targetId = target_id))
end

function execution_step_out(debug_engine::DebugEngine)
    put!(debug_engine.next_cmd, (cmd = :stepOut,))
end

function execution_terminate(debug_engine::DebugEngine)
    put!(debug_engine.next_cmd, (cmd = :stop,))
end

function has_source(debug_engine::DebugEngine, filename::AbstractString)
    return haskey(debug_engine.source_id_by_name, filename)
end

function set_source(debug_engine::DebugEngine, filename::AbstractString, code::AbstractString)
    if !haskey(debug_engine.source_id_by_name, filename)
        source_id = length(debug_engine.sources) + 1
        push!(debug_engine.sources, code)
        debug_engine.source_id_by_name[filename] = source_id
    else
        source_id = debug_engine.source_id_by_name[filename]
        debug_engine.sources[source_id] = code
    end
end

function get_source_id(debug_engine::DebugEngine, filename::AbstractString)
    return debug_engine.source_id_by_name[filename]
end

function get_source(debug_engine::DebugEngine, filename::AbstractString)
    return debug_engine.sources[debug_engine.source_id_by_name[filename]]
end

function get_source(debug_engine::DebugEngine, source_id::Int)
    return debug_engine.sources[source_id]
end

end
