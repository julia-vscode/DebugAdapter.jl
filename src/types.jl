const ChecksumAlgorithm = String
struct ExceptionBreakpointsFilter
    filter::String
    label::String
    default::Union{Nothing,Bool}
end

struct ColumnDescriptor
    attributeName::String
    label::String
    format::Union{Nothing,String}
    type::Union{Nothing,String} # default: "string"
    width::Union{Nothing,Int}
end

struct Capabilities
  supportsConfigurationDoneRequest::Union{Nothing,Bool}
  supportsFunctionBreakpoints::Union{Nothing,Bool}
  supportsConditionalBreakpoints::Union{Nothing,Bool}
  supportsHitConditionalBreakpoints::Union{Nothing,Bool}
  supportsEvaluateForHovers::Union{Nothing,Bool}
  exceptionBreakpointFilters::Vector{ExceptionBreakpointsFilter}
  supportsStepBack::Union{Nothing,Bool}
  supportsSetVariable::Union{Nothing,Bool}
  supportsRestartFrame::Union{Nothing,Bool}
  supportsGotoTargetsRequest::Union{Nothing,Bool}
  supportsStepInTargetsRequest::Union{Nothing,Bool}
  supportsCompletionsRequest::Union{Nothing,Bool}
  supportsModulesRequest::Union{Nothing,Bool}
  additionalModuleColumns::Vector{ColumnDescriptor}
  supportedChecksumAlgorithms::Vector{ChecksumAlgorithm}
  supportsRestartRequest::Union{Nothing,Bool}
  supportsExceptionOptions::Union{Nothing,Bool}
  supportsValueFormattingOptions::Union{Nothing,Bool}
  supportsExceptionInfoRequest::Union{Nothing,Bool}
  supportTerminateDebuggee::Union{Nothing,Bool}
  supportsDelayedStackTraceLoading::Union{Nothing,Bool}
  supportsLoadedSourcesRequest::Union{Nothing,Bool}
  supportsLogPoints::Union{Nothing,Bool}
  supportsTerminateThreadsRequest::Union{Nothing,Bool}
  supportsSetExpression::Union{Nothing,Bool}
  supportsTerminateRequest::Union{Nothing,Bool}
  supportsDataBreakpoints::Union{Nothing,Bool}
  supportsReadMemoryRequest::Union{Nothing,Bool}
  supportsDisassembleRequest::Union{Nothing,Bool}
end

struct Message
    id::Int
    format::String
    variables::Union{Nothing,Dict{String,String}}
    sendTelemetry::Union{Nothing,Bool}
    showUser::Union{Nothing,Bool}
    url::Union{Nothing,String}
    urlLabel::Union{Nothing,String}
end

struct Module
    id::Union{Int,String}
    name::String
    path::Union{Nothing,String}
    isOptimized::Union{Nothing,Bool}
    isUserCode::Union{Nothing,Bool}
    version::Union{Nothing,String}
    symbolStatus::Union{Nothing,String}
    dateTimeStamp::Union{Nothing,String}
    addressRange::Union{Nothing,String}
end

struct ModulesViewDescriptor
    columns::Vector{ColumnDescriptor}
end

struct Thread
    id::Int
    name::String
end

struct Checksum
    algorithm::ChecksumAlgorithm
    checksum::String
end

struct Source
    name::Union{Nothing,String}
    path::Union{Nothing,String}
    sourceReference::Union{Nothing,Int}
    presentationHint::Union{Nothing,String}
    origin::Union{Nothing,String}
    sources::Union{Nothing,Vector{Source}}
    adapterData::Union{Nothing,Any}
    checksums::Union{Nothing,Vector{Checksum}}
end

struct StackFrame
    id::Int
    name::String
    source::Union{Nothing,Source}
    line::Int
    column::Int
    endLine::Union{Nothing,Int}
    endColum::Union{Nothing,Int}
    instructionPointerReference::Union{Nothing,String}
    moduleId::Union{Nothing,Int,String}
    presentationHint::Union{Nothing,String}
end

struct Scope
    name::String
    presentationHint::Union{Nothing,String}
    variablesReference:Int
    namedVariables::Union{Nothing,Int}
    indexedVariables::Union{Nothing,Int}
    expensive::Bool
    source::Union{Nothing,Source}#
    line::Union{Nothing,Int}
    column::Union{Nothing,Int}
    endLine::Union{Nothing,Int}
    endColum::Union{Nothing,Int}
end


struct VariablePresentationHint
    kind::Union{Nothing,String}
    attributes::Union{Nothing,Vector{String}}
    visibility::Union{Nothing,String}
end

struct Variable
    name::String
    value::String
    type::Union{Nothing,String}
    presentatonHint::Union{Nothing,VariablePresentationHint}
    evaluateName::Union{Nothing,String}
    variablesReference::Int
    namedVariables::Union{Nothing,Int}
    indexedVariables::Union{Nothing,Int}
    memoryReference::Union{Nothing,String}
end


struct SourceBreakpoint
    line::Int
    column::Union{Nothing,Int}
    condition::Union{Nothing,String}
    hitCondition::Union{Nothing,String}
    logMessage::Union{Nothing,String}
end

struct FunctionBreakpoint
    name::String
    condition::Union{Nothing,String}
    hitCondition::Union{Nothing,String}
end

const DataBreakpointAccessType = String
struct DataBreakpoint
    dataId::String
    accessType::Union{Nothing,DataBreakpointAccessType}
    condition::Union{Nothing,String}
    hitCondition::Union{Nothing,String}
end

struct Breakpoint
    id::Union{Nothing,Int}
    verified::Bool
    message::Union{Nothing,String}
    source::Union{Nothing,Source}
    line::Union{Nothing,Int}
    column::Union{Nothing,Int}
    endLine::Union{Nothing,Int}
    endColumn::Union{Nothing,Int}
end


struct StepInTarget
    id::Int
    label::String
end

struct GotoTarget
    id::Int    
    label::String
    line::Int
    column::Union{Nothing,Int}
    endLine::Union{Nothing,Int}
    endColumn::Union{Nothing,Int}
    instructionPointerReference::Union{Nothing,String}
end

const CompletionItemType = String
struct CompletionItem
    label::String
    text::Union{Nothing,String}    
    type::CompletionItemType
    start::Union{Nothing,Int}
    length::Union{Nothing,Int}
end

struct ValueFormat
    hex::Union{Nothing,Bool}
end

struct StackFrameFormat
    parameters::Union{Nothing,Bool}
    parameterTypes::Union{Nothing,Bool}
    parameterNames::Union{Nothing,Bool}
    parameterValues::Union{Nothing,Bool}
    line::Union{Nothing,Bool}
    # module::Union{Nothing,Bool}
    includeAll::Union{Nothing,Bool}
end


const ExceptionBreakMode = String
ExceptionBreakModes = ["never", "always", "unhandled", "userUnhandled"]

struct ExceptionPathSegment
    negate::Union{Nothing,Bool}
    names::Vector{String}
end

struct ExceptionOptions
    path::Union{Nothing,Vector{ExceptionPathSegment}}
    breakMode::ExceptionBreakMode
end

struct ExceptionDetails
    message::Union{Nothing,String}
    typeName::Union{Nothing,String}
    fullTypeName::Union{Nothing,String}
    evaluateName::Union{Nothing,String}
    stackTrace::Union{Nothing,String}
    innerException::Union{Nothing,Vector{ExceptionDetails}}
end

struct DisassembledInstruction
    address::String
    instructionBytes::Union{Nothing,String}
    instruction::String
    symbol::Union{Nothing,String}
    location::Union{Nothing,Source}
    line::Union{Nothing,Int}
    column::Union{Nothing,Int}
    endLine::Union{Nothing,Int}
    endColumn::Union{Nothing,Int}
end
