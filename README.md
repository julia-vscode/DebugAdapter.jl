# DebugAdapter

Julia implementation of the Debug Adapter Protocol

## Running the debug adapter

To run a debug session, first instantiate `DebugAdapter.DebugSession` by passing it a connection, which can be a socket, named pipe. Then call `run` on the session:

```julia
import DebugAdapter

# Create or acquire a connection
conn = ... # This should be a Base.IO subtype, for example a named pipe or socket connection

session = DebugAdapter.DebugSession(conn)

run(session)
```

The call to `run` will return once the debug session has finished.

## Julia specific launch and attach arguments

The Julia specific launch arguments can be seen in the type `JuliaLaunchArguments` in this repo. The most important one is `program`, which needs to be an absolute path to a Julia file.

The Julia specific attach arguments can be seen in the type `JuliaAttachArguments` in this repo. Note that even when the debugger is attached, no code will automatically be debugged. Instead, one needs to run the code that should be debugged via a call to `DebugAdapter.debug_code` like this:

```julia
mod = Main # This is the module in which the code should run
code = """
println("Hello world")
""" # This is the code that should be run
filepath = joinpath(homedir(), "something.jl") # This is the filepath that should be used for the debugger
terminate_on_finish = false # Whether the debug session should terminate when the code has finished running

 DebugAdapter.debug_code(session, mod, code, filepath, terminate_on_finish)
 ```
 