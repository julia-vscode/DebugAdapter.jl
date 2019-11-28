using DebugAdapter
server = DebugAdapter.Servers.Server(stdin, stdout)
io = open("/home/zac/tmp/dap_err.txt", "w")
redirect_stderr(io)
# run(server)
while isopen(server.in)
    DebugAdapter.Servers.handle!(server, read(server))
end