
# include("../../VSCodeServer/src/repl.jl")

import Sockets, Base64

module DAPRPC
    using ..JSON

    include("DAPRPC/packagedef.jl")
end
import .DAPRPC: @dict_readable, Outbound

include("DebugEngines.jl")
include("protocol/debug_adapter_protocol.jl")
include("debugger_utils.jl")


struct VariableReference
    kind::Symbol
    value
end

mutable struct DebugSession
    conn
    endpoint::Union{Nothing,DAPRPC.DAPEndpoint}
    debug_engine::Union{Nothing,DebugEngines.DebugEngine}

    varrefs::Vector{VariableReference}

    configuration_done::Channel{Bool}
    attached::Channel{Bool}
    finished_execution::Channel{Bool}

    next_cmd::Channel

    function_breakpoints
    compiled_modules_or_functions::Vector{String}
    compiled_mode::Bool
    stop_on_entry::Bool

    function DebugSession(conn)
        return new(
            conn,
            nothing,
            nothing,
            VariableReference[],
            Channel{Bool}(1),
            Channel{Bool}(1),
            Channel{Bool}(1),
            Channel{Any}(Inf),
            [],
            String[],
            false,
            false
        )
    end
end

function Base.run(debug_session::DebugSession, error_handler=nothing)
    @debug "Connected to debug adapter."

    try
        endpoint = DAPRPC.DAPEndpoint(debug_session.conn, debug_session.conn, error_handler)
        debug_session.endpoint = endpoint
        run(endpoint)

        msg_dispatcher = DAPRPC.MsgDispatcher()
        msg_dispatcher[disconnect_request_type] = params -> disconnect_request(debug_session, params)
        msg_dispatcher[attach_request_type] = params -> attach_request(debug_session, params)
        msg_dispatcher[set_break_points_request_type] = params -> set_break_points_request(debug_session, params)
        msg_dispatcher[set_exception_break_points_request_type] = params -> set_exception_break_points_request(debug_session, params)
        msg_dispatcher[set_function_exception_break_points_request_type] = params -> set_function_break_points_request(debug_session, params)
        msg_dispatcher[stack_trace_request_type] = params -> stack_trace_request(debug_session, params)
        msg_dispatcher[scopes_request_type] = params -> scopes_request(debug_session, params)
        msg_dispatcher[source_request_type] = params -> source_request(debug_session, params)
        msg_dispatcher[variables_request_type] = params -> variables_request(debug_session, params)
        msg_dispatcher[continue_request_type] = params -> continue_request(debug_session, params)
        msg_dispatcher[next_request_type] = params -> next_request(debug_session, params)
        msg_dispatcher[step_in_request_type] = params -> setp_in_request(debug_session, params)
        msg_dispatcher[step_in_targets_request_type] = params -> step_in_targets_request(debug_session, params)
        msg_dispatcher[step_out_request_type] = params -> setp_out_request(debug_session, params)
        msg_dispatcher[evaluate_request_type] = params -> evaluate_request(debug_session, params)
        msg_dispatcher[terminate_request_type] = params -> terminate_request(debug_session, params)
        msg_dispatcher[exception_info_request_type] = params -> exception_info_request(debug_session, params)
        msg_dispatcher[restart_frame_request_type] = params -> restart_frame_request(debug_session, params)
        msg_dispatcher[set_variable_request_type] = params -> set_variable_request(debug_session, params)
        msg_dispatcher[threads_request_type] = params -> threads_request(debug_session, params)
        msg_dispatcher[breakpointslocation_request_type] = params -> breakpointlocations_request(debug_session, params)
        msg_dispatcher[set_compiled_items_notification_type] = params -> set_compiled_items_request(debug_session, params)
        msg_dispatcher[set_compiled_mode_notification_type] = params -> set_compiled_mode_request(debug_session, params)
        msg_dispatcher[initialize_request_type] = params -> initialize_request(debug_session, params)
        msg_dispatcher[launch_request_type] = params -> launch_request(debug_session, params)
        msg_dispatcher[configuration_done_request_type] = params -> configuration_done_request(debug_session, params)

        @async try
            for msg in endpoint
                @async try
                    DAPRPC.dispatch_msg(endpoint, msg_dispatcher, msg)
                catch err
                    if error_handler === nothing
                        Base.display_error(err, catch_backtrace())
                    else
                        error_handler(err, Base.catch_backtrace())
                    end
                end
            end
        catch err
            if error_handler === nothing
                Base.display_error(err, catch_backtrace())
            else
                error_handler(err, Base.catch_backtrace())
            end
        end

        while true
            next_cmd = take!(debug_session.next_cmd)

            if next_cmd.cmd == :terminate
                break
            elseif next_cmd.cmd == :run
                try
                    Main.include(next_cmd.program)
                catch err
                    Base.display_error(stderr, err, catch_backtrace())
                end

                DAPRPC.send(endpoint, terminated_notification_type, TerminatedEventArguments(false))

                # TODO Also send exit code via exited notification
                # DAPRPC.send(endpoint, terminated_notification_type, TerminatedEventArguments(false))
            elseif next_cmd.cmd == :debug
                debug_session.debug_engine = DebugEngines.DebugEngine(
                    next_cmd.mod,
                    next_cmd.code,
                    next_cmd.filename,
                    debug_session.stop_on_entry,
                    (reason, message::Union{String,Nothing}=nothing) -> begin
                        if reason==DebugEngines.StopReasonBreakpoint
                            DAPRPC.send(endpoint, stopped_notification_type, StoppedEventArguments("breakpoint", missing, 1, missing, missing, missing))
                        elseif reason==DebugEngines.StopReasonException
                            DAPRPC.send(endpoint, stopped_notification_type, StoppedEventArguments("exception", missing, 1, missing, message, missing))
                        elseif reason==DebugEngines.StopReasonStep
                            DAPRPC.send(endpoint, stopped_notification_type, StoppedEventArguments("step", missing, 1, missing, missing, missing))
                        elseif reason==DebugEngines.StopReasonEntry
                            DAPRPC.send(endpoint, stopped_notification_type, StoppedEventArguments("entry", missing, 1, missing, missing, missing))
                        else
                            error()
                        end
                    end
                )

                if occursin(r"REPL\[\d*\]", next_cmd.filename)
                    DebugEngines.set_source(debug_session.debug_engine, next_cmd.filename, next_cmd.code)
                end

                DebugEngines.set_function_breakpoints!(debug_session.debug_engine, debug_session.function_breakpoints)
                DebugEngines.set_compiled_functions_modules!(debug_session.debug_engine, debug_session.compiled_modules_or_functions)
                DebugEngines.set_compiled_mode!(debug_session.debug_engine, debug_session.compiled_mode)

                run(debug_session.debug_engine)

                debug_session.debug_engine = nothing

                DAPRPC.send(endpoint, terminated_notification_type, TerminatedEventArguments(false))

                put!(debug_session.finished_execution, true)
            else
                error("Unknown command")
            end
        end

        @debug "Finished debugging"
    catch err
        if error_handler === nothing
            rethrow(err)
        else
            error_handler(err, Base.catch_backtrace())
        end
    end
end

function debug_code(debug_session::DebugSession, mod::Module, code::String, filename::String)
    fetch(debug_session.attached)

    put!(debug_session.next_cmd, (cmd=:debug, mod=mod, code=code, filename=filename))

    take!(debug_session.finished_execution)
end

function terminate(debug_session::DebugSession)
    if debug_session.debug_engine!==nothing
        DebugEngines.execution_terminate(debug_session.debug_engine)
    end
end

function Base.close(debug_session::DebugSession)
    put!(debug_session.next_cmd, (;cmd=:terminate))
end

include("debugger_requests.jl")
