
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

    terminate_on_finish::Bool

    sources::Dict{Int,String}
    next_source_id::Int
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
            true,
            Dict{Int,String}(),
            1,
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
        msg_dispatcher[disconnect_request_type] = (dap_endpoint, params) -> disconnect_request(dap_endpoint, debug_session, params)
        msg_dispatcher[attach_request_type] = (dap_endpoint, params) -> attach_request(dap_endpoint, debug_session, params)
        msg_dispatcher[set_break_points_request_type] = (dap_endpoint, params) -> set_break_points_request(dap_endpoint, debug_session, params)
        msg_dispatcher[set_exception_break_points_request_type] = (dap_endpoint, params) -> set_exception_break_points_request(dap_endpoint, debug_session, params)
        msg_dispatcher[set_function_exception_break_points_request_type] = (dap_endpoint, params) -> set_function_break_points_request(dap_endpoint, debug_session, params)
        msg_dispatcher[stack_trace_request_type] = (dap_endpoint, params) -> stack_trace_request(dap_endpoint, debug_session, params)
        msg_dispatcher[scopes_request_type] = (dap_endpoint, params) -> scopes_request(dap_endpoint, debug_session, params)
        msg_dispatcher[source_request_type] = (dap_endpoint, params) -> source_request(dap_endpoint, debug_session, params)
        msg_dispatcher[variables_request_type] = (dap_endpoint, params) -> variables_request(dap_endpoint, debug_session, params)
        msg_dispatcher[continue_request_type] = (dap_endpoint, params) -> continue_request(dap_endpoint, debug_session, params)
        msg_dispatcher[next_request_type] = (dap_endpoint, params) -> next_request(dap_endpoint, debug_session, params)
        msg_dispatcher[step_in_request_type] = (dap_endpoint, params) -> setp_in_request(dap_endpoint, debug_session, params)
        msg_dispatcher[step_in_targets_request_type] = (dap_endpoint, params) -> step_in_targets_request(dap_endpoint, debug_session, params)
        msg_dispatcher[step_out_request_type] = (dap_endpoint, params) -> setp_out_request(dap_endpoint, debug_session, params)
        msg_dispatcher[evaluate_request_type] = (dap_endpoint, params) -> evaluate_request(dap_endpoint, debug_session, params)
        msg_dispatcher[terminate_request_type] = (dap_endpoint, params) -> terminate_request(dap_endpoint, debug_session, params)
        msg_dispatcher[exception_info_request_type] = (dap_endpoint, params) -> exception_info_request(dap_endpoint, debug_session, params)
        msg_dispatcher[restart_frame_request_type] = (dap_endpoint, params) -> restart_frame_request(dap_endpoint, debug_session, params)
        msg_dispatcher[set_variable_request_type] = (dap_endpoint, params) -> set_variable_request(dap_endpoint, debug_session, params)
        msg_dispatcher[threads_request_type] = (dap_endpoint, params) -> threads_request(dap_endpoint, debug_session, params)
        msg_dispatcher[breakpointslocation_request_type] = (dap_endpoint, params) -> breakpointlocations_request(dap_endpoint, debug_session, params)
        msg_dispatcher[set_compiled_items_notification_type] = (dap_endpoint, params) -> set_compiled_items_request(dap_endpoint, debug_session, params)
        msg_dispatcher[set_compiled_mode_notification_type] = (dap_endpoint, params) -> set_compiled_mode_request(dap_endpoint, debug_session, params)
        msg_dispatcher[initialize_request_type] = (dap_endpoint, params) -> initialize_request(dap_endpoint, debug_session, params)
        msg_dispatcher[launch_request_type] = (dap_endpoint, params) -> launch_request(dap_endpoint, debug_session, params)
        msg_dispatcher[configuration_done_request_type] = (dap_endpoint, params) -> configuration_done_request(dap_endpoint, debug_session, params)

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

                if debug_session.terminate_on_finish
                    break
                end
            elseif next_cmd.cmd == :debug
                debug_session.debug_engine = DebugEngines.DebugEngine(
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

                DebugEngines.set_function_breakpoints!(debug_session.debug_engine, debug_session.function_breakpoints)
                DebugEngines.set_compiled_functions_modules!(debug_session.debug_engine, debug_session.compiled_modules_or_functions)
                DebugEngines.set_compiled_mode!(debug_session.debug_engine, debug_session.compiled_mode)

                run(debug_session.debug_engine)

                debug_session.debug_engine = nothing

                put!(debug_session.finished_execution, true)

                if debug_session.terminate_on_finish
                    break
                end
            else
                error("Unknown command")
            end
        end

        DAPRPC.send(endpoint, terminated_notification_type, TerminatedEventArguments(false))

        @debug "Finished debugging"
    catch err
        if error_handler === nothing
            rethrow(err)
        else
            error_handler(err, Base.catch_backtrace())
        end
    end
end

function debug_code(debug_session::DebugSession, code::String, filename::String, terminate_on_finish::Bool)
    fetch(debug_session.attached)

    debug_session.terminate_on_finish = terminate_on_finish

    put!(debug_session.next_cmd, (cmd=:debug, code=code, filename=filename))

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
