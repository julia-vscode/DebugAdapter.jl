import JSON

struct Comm
    in::IO
    out::IO
end

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

function Base.put!(comm::Comm, pm::ProtocolMessage)
    write(comm.out, encode(pm))
end

function Base.take!(comm::Comm)
    buf = readuntil(comm.in, "\r\n\r\n", keep=true)
    nb = parse(Int64, match(r"Content-Length:\s*([0-9]*)"s, buf)[1])
    apppend!(buf, read(comm.in, nb))
    decode(buf)
end
