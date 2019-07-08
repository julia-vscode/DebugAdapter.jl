abstract type ProtocolMessage end
export ProtocolMessage

# Subtypes of `ProtocolMessage` provide a custom definition for dispatch on construction
# from a Dict.
function protocol_message_type(t::Type{Val{S}}) where S
    @error "Protocol message type $(t.parameters[1]) undefined."
end
export protocol_message_type

# the top-level constructor for serialization from a Dict.
ProtocolMessage(d::Dict) = protocol_message_type(Val{Symbol(d["type"])})(d)

