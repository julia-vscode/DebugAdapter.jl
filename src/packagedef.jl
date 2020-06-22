
our_findfirst(ch::AbstractChar, string::AbstractString) = findfirst(==(ch), string)
our_findnext(ch::AbstractChar, string::AbstractString, ind::Integer) = findnext(==(ch), string, ind)

include("../../../error_handler.jl")

include("../../VSCodeServer/src/repl.jl")

import Sockets, Base64

include("protocol/debug_adapter_protocol.jl")
include("debugger_utils.jl")
include("debugger_core.jl")
include("debugger_requests.jl")


function clean_up_ARGS_in_launch_mode()
    pipename = ARGS[1]
    crashreporting_pipename = ARGS[2]
    deleteat!(ARGS, 1)
    deleteat!(ARGS, 1)

    if ENV["JL_ARGS"] != ""
        cmd_ln_args_encoded = split(ENV["JL_ARGS"], ';')

        delete!(ENV, "JL_ARGS")

        cmd_ln_args_decoded = map(i->String(Base64.base64decode(i)), cmd_ln_args_encoded)

        for arg in cmd_ln_args_decoded
            push!(ARGS, arg)
        end
    end

    return pipename, crashreporting_pipename
end

function startdebug(pipename)
    @debug "Trying to connect to debug adapter."
    conn = Sockets.connect(pipename)
    try
        @debug "Connected to debug adapter."

        endpoint = JSONRPC.JSONRPCEndpoint(conn, conn) # TODO What about err_handler here?

        run(endpoint)

        state = DebuggerState()

        msg_dispatcher = JSONRPC.MsgDispatcher()
        msg_dispatcher[disconnect_request_type] = (conn, params)->disconnect_request(conn, state, params)
        msg_dispatcher[run_notification_type] = (conn, params)->run_notification(conn, state, params)
        msg_dispatcher[debug_notification_type] = (conn, params)->debug_notification(conn, state, params)

        msg_dispatcher[exec_notification_type] = (conn, params)->exec_notification(conn, state, params)
        msg_dispatcher[set_break_points_request_type] = (conn, params)->set_break_points_request(conn, state, params)
        msg_dispatcher[set_exception_break_points_request_type] = (conn, params)->set_exception_break_points_request(conn, state, params)
        msg_dispatcher[set_function_exception_break_points_request_type] = (conn, params)->set_function_break_points_request(conn, state, params)
        msg_dispatcher[stack_trace_request_type] = (conn, params)->stack_trace_request(conn, state, params)
        msg_dispatcher[scopes_request_type] = (conn, params)->scopes_request(conn, state, params)
        msg_dispatcher[source_request_type] = (conn, params)->source_request(conn, state, params)
        msg_dispatcher[variables_request_type] = (conn, params)->variables_request(conn, state, params)
        msg_dispatcher[continue_request_type] = (conn, params)->continue_request(conn, state, params)
        msg_dispatcher[next_request_type] = (conn, params)->next_request(conn, state, params)
        msg_dispatcher[step_in_request_type] = (conn, params)->setp_in_request(conn, state, params)
        msg_dispatcher[step_out_request_type] = (conn, params)->setp_out_request(conn, state, params)
        msg_dispatcher[evaluate_request_type] = (conn, params)->evaluate_request(conn, state, params)
        msg_dispatcher[terminate_request_type] = (conn, params)->terminate_request(conn, state, params)
        msg_dispatcher[exception_info_request_type] = (conn, params)->exception_info_request(conn, state, params)
        msg_dispatcher[restart_frame_request_type] = (conn, params)->restart_frame_request(conn, state, params)
        msg_dispatcher[set_variable_request_type] = (conn, params)->set_variable_request(conn, state, params)

        @async try
            while true
                @debug "Waiting for next command from debug adapter."
                msg = JSONRPC.get_next_message(endpoint)

                JSONRPC.dispatch_msg(endpoint, msg_dispatcher, msg)
            end
        catch err
            # TODO Add crash reporting
        end

        while true
            msg = take!(state.next_cmd)

            if msg.cmd == :run
                try
                    include(msg.program)
                catch err
                    Base.display_error(stderr, err, catch_backtrace())
                end

                JSONRPC.send(conn, finished_notification_type, nothing)
                break
            elseif msg.cmd == :stop
                break
            else
                ret = if msg.cmd == :continue
                    our_debug_command(:c, state)
                elseif msg.cmd == :next
                    our_debug_command(:n, state)
                elseif msg.cmd == :stepIn
                    our_debug_command(:s, state)
                elseif msg.cmd == :stepOut
                    our_debug_command(:finish, state)
                end

                if ret === nothing
                    JSONRPC.send(conn, finished_notification_type, nothing)
                    state.debug_mode == :launch && return :break
                else
                    send_stopped_msg(conn, ret, state)
                end
            end
        end

        @debug "Finished debugging"
    finally
close(conn)
    end
end
