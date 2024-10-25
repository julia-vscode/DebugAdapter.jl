struct DAPError <: Exception
    msg::AbstractString
end

mutable struct DAPEndpoint{IOIn<:IO,IOOut<:IO}
    pipe_in::IOIn
    pipe_out::IOOut

    out_msg_queue::Channel{Any}
    in_msg_queue::Channel{Any}

    outstanding_requests::Dict{String,Channel{Any}}

    err_handler::Union{Nothing,Function}

    status::Symbol

    read_task::Union{Nothing,Task}
    write_task::Union{Nothing,Task}

    seq::Int
end

DAPEndpoint(pipe_in, pipe_out, err_handler=nothing) =
    DAPEndpoint(pipe_in, pipe_out, Channel{Any}(Inf), Channel{Any}(Inf), Dict{String,Channel{Any}}(), err_handler, :idle, nothing, nothing, 0)

function write_transport_layer(stream, response)
    response_utf8 = transcode(UInt8, response)
    n = length(response_utf8)
    write(stream, "Content-Length: $n\r\n\r\n")
    write(stream, response_utf8)
    flush(stream)
end

function read_transport_layer(stream)
    try
        header_dict = Dict{String,String}()
        line = chomp(readline(stream))
        # Check whether the socket was closed
        if line == ""
            return nothing
        end
        while length(line) > 0
            h_parts = split(line, ":")
            header_dict[chomp(h_parts[1])] = chomp(h_parts[2])
            line = chomp(readline(stream))
        end
        message_length = parse(Int, header_dict["Content-Length"])
        message_str = String(read(stream, message_length))
        return message_str
    catch err
        if err isa Base.IOError
            return nothing
        end

        rethrow(err)
    end
end

Base.isopen(x::DAPEndpoint) = x.status != :closed && isopen(x.pipe_in) && isopen(x.pipe_out)

function Base.run(x::DAPEndpoint)
    x.status == :idle || error("Endpoint is not idle.")

    x.write_task = @async try
        try
            for msg in x.out_msg_queue
                if isopen(x.pipe_out)
                    write_transport_layer(x.pipe_out, msg)
                else
                    # TODO Reconsider at some point whether this should be treated as an error.
                    break
                end
            end
        finally
            close(x.out_msg_queue)
        end
    catch err
        bt = catch_backtrace()
        if x.err_handler !== nothing
            x.err_handler(err, bt)
        else
            Base.display_error(stderr, err, bt)
        end
    end

    x.read_task = @async try
        while true
            message = read_transport_layer(x.pipe_in)

            if message === nothing || x.status == :closed
                break
            end

            message_dict = JSON.parse(message)

            if message_dict["type"] == "request" || message_dict["type"] == "event"
                try
                    put!(x.in_msg_queue, message_dict)
                catch err
                    if err isa InvalidStateException
                        break
                    else
                        rethrow(err)
                    end
                end
            elseif message_dict["type"] == "response"
                # This must be a response
                id_of_request = message_dict["request_seq"]

                channel_for_response = x.outstanding_requests[id_of_request]
                put!(channel_for_response, message_dict)
            else
                error("Unknown message")
            end
        end

        close(x.in_msg_queue)

        for i in values(x.outstanding_requests)
            close(i)
        end

        x.status = :closed
    catch err
        bt = catch_backtrace()
        if x.err_handler !== nothing
            x.err_handler(err, bt)
        else
            Base.display_error(stderr, err, bt)
        end
    end

    x.status = :running
end

function send_notification(x::DAPEndpoint, method::AbstractString, params)
    check_dead_endpoint!(x)

    x.seq += 1

    message = Dict("seq" => x.seq, "type" => "event", "event" => method, "body" => params)

    message_json = JSON.json(message)

    put!(x.out_msg_queue, message_json)

    yield()

    return nothing
end

function send_request(x::DAPEndpoint, method::AbstractString, params)
    check_dead_endpoint!(x)

    x.seq += 1

    message = Dict("seq" => x.seq, "type" => "request", "command" => method, "arguments" => params)

    response_channel = Channel{Any}(1)
    x.outstanding_requests[x.seq] = response_channel

    message_json = JSON.json(message)

    put!(x.out_msg_queue, message_json)

    response = take!(response_channel)

    if response["success"] == true
        return response["body"]
    elseif response["success"] == false
        error_message = response["message"]
        throw(DAPError(error_message))
    else
        throw(DAPError("ERROR AT THE TRANSPORT LEVEL"))
    end
end

function get_next_message(endpoint::DAPEndpoint)
    check_dead_endpoint!(endpoint)

    msg = take!(endpoint.in_msg_queue)

    return msg
end

function Base.iterate(endpoint::DAPEndpoint, state=nothing)
    check_dead_endpoint!(endpoint)

    try
        return take!(endpoint.in_msg_queue), nothing
    catch err
        if err isa InvalidStateException
            return nothing
        else
            rethrow(err)
        end
    end
end

function send_success_response(endpoint, original_request, result)
    check_dead_endpoint!(endpoint)

    endpoint.seq += 1

    response = Dict("seq" => endpoint.seq, "type" => "response", "request_seq" => original_request["seq"], "success" => true, "command" => original_request["command"], "body" => result)

    response_json = JSON.json(response)

    put!(endpoint.out_msg_queue, response_json)
end

function send_error_response(endpoint, original_request, code, message, data)
    check_dead_endpoint!(endpoint)

    endpoint.seq += 1

    response = Dict("seq" => endpoint.seq, "request_seq" => original_request["seq"], "error" => Dict("code" => code, "message" => message, "data" => data))

    response_json = JSON.json(response)

    put!(endpoint.out_msg_queue, response_json)
end

function Base.close(endpoint::DAPEndpoint)
    endpoint.status == :closed && return

    flush(endpoint)

    endpoint.status = :closed
    isopen(endpoint.in_msg_queue) && close(endpoint.in_msg_queue)
    isopen(endpoint.out_msg_queue) && close(endpoint.out_msg_queue)

    fetch(endpoint.write_task)
    # TODO we would also like to close the read Task
    # But unclear how to do that without also closing
    # the socket, which we don't want to do
    # fetch(endpoint.read_task)
end

function Base.flush(endpoint::DAPEndpoint)
    check_dead_endpoint!(endpoint)

    while isready(endpoint.out_msg_queue)
        yield()
    end
end

function check_dead_endpoint!(endpoint)
    status = endpoint.status
    status === :running && return
    error("Endpoint is not running, the current state is $(status).")
end
