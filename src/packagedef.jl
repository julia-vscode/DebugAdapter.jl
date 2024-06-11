
# include("../../VSCodeServer/src/repl.jl")

import Sockets, Base64

module DAPRPC
    using ..JSON

    include("DAPRPC/packagedef.jl")
end
import .DAPRPC: @dict_readable, Outbound

include("protocol/debug_adapter_protocol.jl")
include("debugger_utils.jl")
include("debugger_core.jl")
include("debugger_requests.jl")

function debug_code(debug_session::DebugSession, code::String, file::String)
    # Wait until the debugger is ready
    fetch(debug_session.ready)

    debug_session.sources[0] = code

    # @debug "setting source_path" file = params.file
    put!(debug_session.next_cmd, (cmd = :set_source_path, source_path = file))

    ex = Meta.parse(code)
    debug_session.expr_splitter = JuliaInterpreter.ExprSplitter(Main, ex) # TODO: line numbers ?
    debug_session.frame = get_next_top_level_frame(debug_session)

    if isready(debug_session.finished_running_code)
        take!(debug_session.finished_running_code)
    end

    if debug_session.stopOnEntry
        DAPRPC.send(debug_session.endpoint, stopped_notification_type, StoppedEventArguments("entry", missing, 1, missing, missing, missing))
    elseif JuliaInterpreter.shouldbreak(debug_session.frame, debug_session.frame.pc)
        DAPRPC.send(debug_session.endpoint, stopped_notification_type, StoppedEventArguments("breakpoint", missing, 1, missing, missing, missing))
    else
        put!(debug_session.next_cmd, (cmd = :continue,))
    end

    take!(debug_session.finished_running_code)
end

function terminate(debug_session::DebugSession)
    put!(debug_session.next_cmd, (cmd = :stop,))
end

function Base.run(state::DebugSession, error_handler=nothing)
    @debug "Connected to debug adapter."

    try

        endpoint = DAPRPC.DAPEndpoint(state.conn, state.conn, error_handler)

        state.endpoint = endpoint

        run(endpoint)

        msg_dispatcher = DAPRPC.MsgDispatcher()
        msg_dispatcher[disconnect_request_type] = (conn, params) -> disconnect_request(conn, state, params)

        msg_dispatcher[attach_request_type] = (conn, params) -> attach_request(conn, state, params)
        msg_dispatcher[set_break_points_request_type] = (conn, params) -> set_break_points_request(conn, state, params)
        msg_dispatcher[set_exception_break_points_request_type] = (conn, params) -> set_exception_break_points_request(conn, state, params)
        msg_dispatcher[set_function_exception_break_points_request_type] = (conn, params) -> set_function_break_points_request(conn, state, params)
        msg_dispatcher[stack_trace_request_type] = (conn, params) -> stack_trace_request(conn, state, params)
        msg_dispatcher[scopes_request_type] = (conn, params) -> scopes_request(conn, state, params)
        msg_dispatcher[source_request_type] = (conn, params) -> source_request(conn, state, params)
        msg_dispatcher[variables_request_type] = (conn, params) -> variables_request(conn, state, params)
        msg_dispatcher[continue_request_type] = (conn, params) -> continue_request(conn, state, params)
        msg_dispatcher[next_request_type] = (conn, params) -> next_request(conn, state, params)
        msg_dispatcher[step_in_request_type] = (conn, params) -> setp_in_request(conn, state, params)
        msg_dispatcher[step_in_targets_request_type] = (conn, params) -> step_in_targets_request(conn, state, params)
        msg_dispatcher[step_out_request_type] = (conn, params) -> setp_out_request(conn, state, params)
        msg_dispatcher[evaluate_request_type] = (conn, params) -> evaluate_request(conn, state, params)
        msg_dispatcher[terminate_request_type] = (conn, params) -> terminate_request(conn, state, params)
        msg_dispatcher[exception_info_request_type] = (conn, params) -> exception_info_request(conn, state, params)
        msg_dispatcher[restart_frame_request_type] = (conn, params) -> restart_frame_request(conn, state, params)
        msg_dispatcher[set_variable_request_type] = (conn, params) -> set_variable_request(conn, state, params)
        msg_dispatcher[threads_request_type] = (conn, params) -> threads_request(conn, state, params)
        msg_dispatcher[breakpointslocation_request_type] = (conn, params) -> breakpointlocations_request(conn, state, params)
        msg_dispatcher[set_compiled_items_notification_type] = (conn, params) -> set_compiled_items_request(conn, state, params)
        msg_dispatcher[set_compiled_mode_notification_type] = (conn, params) -> set_compiled_mode_request(conn, state, params)
        msg_dispatcher[initialize_request_type] = (conn, params) -> initialize_request(conn, state, params)
        msg_dispatcher[launch_request_type] = (conn, params) -> launch_request(conn, state, params)
        msg_dispatcher[configuration_done_request_type] = (conn, params) -> configuration_done_request(conn, state, params)

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
            msg = take!(state.next_cmd)

            ret = nothing

            if msg.cmd == :run
                try
                    Main.include(msg.program)
                catch err
                    Base.display_error(stderr, err, catch_backtrace())
                end

                break
            elseif msg.cmd == :stop
                break
            elseif msg.cmd == :set_source_path
                task_local_storage()[:SOURCE_PATH] = msg.source_path
            else
                if msg.cmd == :continue
                    ret = our_debug_command(:c, state)
                elseif msg.cmd == :next
                    ret = our_debug_command(:n, state)
                elseif msg.cmd == :stepIn
                    if msg.targetId === missing
                        ret = our_debug_command(:s, state)
                    else
                        itr = 0
                        success = true
                        while state.frame.pc < msg.targetId
                            ret = our_debug_command(:nc, state)
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
                            ret = our_debug_command(:s, state)
                        end
                    end
                elseif msg.cmd == :stepOut
                    ret = our_debug_command(:finish, state)
                end

                if ret === nothing
                    state.debug_mode == :launch && break
                    put!(state.finished_running_code, true)
                else
                    send_stopped_msg(endpoint, ret, state)
                end
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
