using JuliaInterpreter

const last_seq = Ref{Int64}()
seq!() = last_seq.x += 1

const default_capabilities = Capabilities(;)

handle(m::ProtocolMessage) = @error "Unexpected protocol message: $m."

function loop(comm::Comm)
    while isopen(comm.in)
        map(m -> put!(comm, m), handle(get!(comm)))
    end
end
