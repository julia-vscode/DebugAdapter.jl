@dict_readable struct JuliaLaunchArguments <: Outbound
    noDebug::Union{Missing,Bool}
    __restart::Union{Missing,Any}
    program::String
    stopOnEntry::Union{Missing,Bool}
    cwd::Union{Missing,String}
    env::Union{Missing,Dict{String,String}}
    project::Union{Missing,String}
    args::Union{Missing,Vector{String}}
    compiledModulesOrFunctions::Union{Missing,Vector{String}}
    compiledMode::Union{Missing,Bool}
end

@dict_readable struct JuliaAttachArguments <: Outbound
    __restart::Union{Missing,Any}
    stopOnEntry::Bool
    compiledModulesOrFunctions::Union{Missing,Vector{String}}
    compiledMode::Union{Missing,Bool}
end

const disconnect_request_type = DAPRPC.RequestType("disconnect", DisconnectArguments, DisconnectResponseArguments)
const set_break_points_request_type = DAPRPC.RequestType("setBreakpoints", SetBreakpointsArguments, SetBreakpointsResponseArguments)
const set_exception_break_points_request_type = DAPRPC.RequestType("setExceptionBreakpoints", SetExceptionBreakpointsArguments, SetExceptionBreakpointsResponseArguments)
const set_function_exception_break_points_request_type = DAPRPC.RequestType("setFunctionBreakpoints", SetFunctionBreakpointsArguments, SetFunctionBreakpointsResponseArguments)
const stack_trace_request_type = DAPRPC.RequestType("stackTrace", StackTraceArguments, StackTraceResponseArguments)
const scopes_request_type = DAPRPC.RequestType("scopes", ScopesArguments, ScopesResponseArguments)
const source_request_type = DAPRPC.RequestType("source", SourceArguments, SourceResponseArguments)
const variables_request_type = DAPRPC.RequestType("variables", VariablesArguments, VariablesResponseArguments)
const continue_request_type = DAPRPC.RequestType("continue", ContinueArguments, ContinueResponseArguments)
const next_request_type = DAPRPC.RequestType("next", NextArguments, NextResponseArguments)
const step_in_request_type = DAPRPC.RequestType("stepIn", StepInArguments, StepInResponseArguments)
const step_in_targets_request_type = DAPRPC.RequestType("stepInTargets", StepInTargetsArguments, StepInTargetsResponseArguments)
const step_out_request_type = DAPRPC.RequestType("stepOut", StepOutArguments, StepOutResponseArguments)
const evaluate_request_type = DAPRPC.RequestType("evaluate", EvaluateArguments, EvaluateResponseArguments)
const terminate_request_type = DAPRPC.RequestType("terminate", TerminateArguments, TerminateResponseArguments)
const exception_info_request_type = DAPRPC.RequestType("exceptionInfo", ExceptionInfoArguments, ExceptionInfoResponseArguments)
const restart_frame_request_type = DAPRPC.RequestType("restartFrame", RestartFrameArguments, RestartFrameResponseResponseArguments)
const set_variable_request_type = DAPRPC.RequestType("setVariable", SetVariableArguments, SetVariableResponseArguments)
const stopped_notification_type = DAPRPC.EventType("stopped", StoppedEventArguments)
const threads_request_type = DAPRPC.RequestType("threads", Nothing, ThreadsResponseArguments)
const breakpointslocation_request_type = DAPRPC.RequestType("breakpointLocations", BreakpointLocationsArguments, BreakpointLocationsResponseArguments)
const initialize_request_type = DAPRPC.RequestType("initialize", InitializeRequestArguments, Capabilities)
const launch_request_type = DAPRPC.RequestType("launch", JuliaLaunchArguments, LaunchResponseArguments)
const attach_request_type = DAPRPC.RequestType("attach", JuliaAttachArguments, AttachResponseArguments)
const initialized_notification_type = DAPRPC.EventType("initialized", InitializedEventArguments)
const configuration_done_request_type = DAPRPC.RequestType("configurationDone", Union{ConfigurationDoneArguments,Nothing}, ConfigurationDoneResponseArguments)
const terminated_notification_type = DAPRPC.EventType("terminated", TerminatedEventArguments)

@dict_readable struct DebugArguments <: Outbound
    stopOnEntry::Bool
    program::String
    compiledModulesOrFunctions::Union{Missing,Vector{String}}
    compiledMode::Union{Missing,Bool}
end



# Our own requests
const set_compiled_items_notification_type = DAPRPC.EventType("setCompiledItems", SetCompiledItemsArguments)
const set_compiled_mode_notification_type = DAPRPC.EventType("setCompiledMode", SetCompiledModeArguments)
