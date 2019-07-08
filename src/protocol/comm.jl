# *** message marshaling ***

function encode(pm::ProtocolMessage)
    buf = IOBuffer()
    JSON.print(buf, JSON.lower(pm))
    seek(buf, 0)
    payload = read(buf)
    prepend!(payload, transcode(UInt8, "Content-Length: $(length(payload))\r\n\r\n"))
end

function decode(bytes::Vector{UInt8})
    match = match(r"Content-Length:\s*([0-9]*)(.*?)\r\n\r\n(.*)$"s, transcode(String, bytes))
    json = match[3]
    @assert parse(Int64, match[1]) == sizeof(json)
    ProtocolMessage(JSON.parse(json))
end

# Comm: a communication state abstraction
struct Comm{STATE}
    in::IO
    out::IO
    last_seq::Ref{Int64}
    state::STATE

    function Comm{STATE}(in, out, state) where STATE
        new(in, out, Ref(0), state)
    end
end
export Comm

# returns the next message ID
seq!(comm::Comm) = comm.last_seq.x += 1

# send a generic message
function Base.write(comm::Comm, pm::ProtocolMessage)
    write(comm.out, encode(pm))
end

# receive a generic message
function Base.read(comm::Comm)
    buf = readuntil(comm.in, "\r\n\r\n", keep=true)
    nb = parse(Int64, match(r"Content-Length:\s*([0-9]*)"s, buf)[1])
    apppend!(buf, read(comm.in, nb))
    decode(buf)
end

# send a response to a request
function respond!(comm::Comm, request::Request, body; success::Bool=true, message::Union{Missing,String}=missing)
    # ensure response type matches request type
    @assert request_command(request) == response_command(body)

    # construct and send our response
    write(comm, Response{Q}(seq=seq!(comm), request_seq=request.seq, body=body,
        success=success, message=message))
end
export respond!

# send a request
function request!(comm::Comm, body::T) where T
    write(comm, Request{T}(seq=seq!(comm), body=body))
end
export request!

# send an event
function signal!(comm::Comm, body::T) where T
    write(comm, Event{T}(seq=seq!(comm), body=body))
end
export signal!
