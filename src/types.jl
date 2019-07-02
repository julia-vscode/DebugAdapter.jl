# *** enumerations ***

const ChecksumAlgorithm = String
const ChecksumAlgorithms = ("MD5", "SHA1", "SHA256", "timestamp")

const ColumnDescriptorType = String
const ColumnDescriptorTypes = ("string", "number", "boolean", "unixTimestampUTC")

const CompletionItemType = String
const CompletionItemTypes = ("method", "function", "constructor", "field", "variable",
    "class", "interface", "module", "property", "unit", "value", "enum", "keyword",
    "snippet", "text", "color", "file", "reference", "customcolor")

const DataBreakpointAccessType = String
const DataBreakpointAccessTypes = ("read", "write", "readWrite")

const ExceptionBreakMode = String
const ExceptionBreakModes = ("never", "always", "unhandled", "userUnhandled")

const LoadedReason = String
const LoadedReasons = ("new", "changed", "removed")

const OutputCategory = String
const OutputCategories = ("console", "stdout", "stderr", "telemetry")

const PathFormat = String
const PathFormats = ("path", "uri")

const ScopePresentationHint = String
const ScopePresentationHints = ("arguments", "locals", "registers")

const SourcePresentationHint = String
const SourcePresentationHints = ("normal", "emphasize", "deemphasize")

const StackFramePresentationHint = String
const StackFramePresentationHints = ("normal", "label", "subtle")

const StartMethod = String
const StartMethods = ("launch", "attach", "attachForSuspendedLaunch")

const StoppedReason = String
const StoppedReasons = ("step", "breakpoint", "exception", "pause", "entry", "goto",
    "function breakpoint", "data breakpoint")

const TerminalKind = String
const TerminalKinds = ("integrated", "external")

const VariablePresentationHintAttribute = String
const VariablePresentationHintAttributes = ("static", "constant", "readOnly", "rawString",
    "hasObjectId", "canHaveObjectId", "hasSideEffects")

const VariablePresentationHintKind = String
const VariablePresentationHintkinds = ("property", "method", "class", "data", "event",
    "baseClass", "innerClass", "interface", "mostDerivedClass", "virtual", "dataBreakpoint")

const VariablePresentationHintVisibility = String
const VariablePresentationHintVisibilities = ("public", "private", "protected", "internal",
    "final")

const VariablesFilter = String
const VariablesFilters = ("indexed", "named")


# *** structured types ***

@dictable struct Checksum
    algorithm::ChecksumAlgorithm
    checksum::String
end

@dictable struct Source
    name::Union{Missing,String} = missing
    path::Union{Missing,String} = missing
    sourceReference::Union{Missing,Int64} = missing
    presentationHint::Union{Missing,SourcePresentationHint} = missing
    origin::Union{Missing,String} = missing
    sources::Union{Missing,Vector{Source}} = missing
    adapterData::Union{Missing,Any} = missing
    checksums::Union{Missing,Vector{Checksum}} = missing
end

@dictable struct Breakpoint
    id::Union{Missing,Int64} = missing
    verified::Bool
    message::Union{Missing,String} = missing
    source::Union{Missing,Source} = missing
    line::Union{Missing,Int64} = missing
    column::Union{Missing,Int64} = missing
    endLine::Union{Missing,Int64} = missing
    endColumn::Union{Missing,Int64} = missing
end

@dictable struct ColumnDescriptor
    attributeName::String
    label::String
    format::Union{Missing,String} = missing
    type::Union{Missing,ColumnDescriptorType} = missing
    width::Union{Missing,Int64} = missing
end

@dictable struct ExceptionBreakpointsFilter
    filter::String
    label::String
    default::Union{Missing,Bool} = missing
end

@dictable struct Capabilities
    supportsConfigurationDoneRequest::Union{Missing,Bool} = missing
    supportsFunctionBreakpoints::Union{Missing,Bool} = missing
    supportsConditionalBreakpoints::Union{Missing,Bool} = missing
    supportsHitConditionalBreakpoints::Union{Missing,Bool} = missing
    supportsEvaluateForHovers::Union{Missing,Bool} = missing
    exceptionBreakpointFilters::Union{Missing,Vector{ExceptionBreakpointsFilter}} = missing
    supportsStepBack::Union{Missing,Bool} = missing
    supportsSetVariable::Union{Missing,Bool} = missing
    supportsRestartFrame::Union{Missing,Bool} = missing
    supportsGotoTargetsRequest::Union{Missing,Bool} = missing
    supportsStepInTargetsRequest::Union{Missing,Bool} = missing
    supportsCompletionsRequest::Union{Missing,Bool} = missing
    supportsModulesRequest::Union{Missing,Bool} = missing
    additionalModuleColumns::Union{Missing,Vector{ColumnDescriptor}} = missing
    supportedChecksumAlgorithms::Union{Missing,Vector{ChecksumAlgorithm}} = missing
    supportsRestartRequest::Union{Missing,Bool} = missing
    supportsExceptionOptions::Union{Missing,Bool} = missing
    supportsValueFormattingOptions::Union{Missing,Bool} = missing
    supportsExceptionInfoRequest::Union{Missing,Bool} = missing
    supportTerminateDebuggee::Union{Missing,Bool} = missing
    supportsDelayedStackTraceLoading::Union{Missing,Bool} = missing
    supportsLoadedSourcesRequest::Union{Missing,Bool} = missing
    supportsLogPoints::Union{Missing,Bool} = missing
    supportsTerminateThreadsRequest::Union{Missing,Bool} = missing
    supportsSetExpression::Union{Missing,Bool} = missing
    supportsTerminateRequest::Union{Missing,Bool} = missing
    supportsDataBreakpoints::Union{Missing,Bool} = missing
    supportsReadMemoryRequest::Union{Missing,Bool} = missing
    supportsDisassembleRequest::Union{Missing,Bool} = missing
end

@dictable struct CompletionItem
    label::String
    text::Union{Missing,String} = missing
    type::Union{Missing, CompletionItemType} = missing
    start::Union{Missing,Int64} = missing
    length::Union{Missing,Int64} = missing
end

@dictable struct DataBreakpoint
    dataId::String
    accessType::Union{Missing,DataBreakpointAccessType} = missing
    condition::Union{Missing,String} = missing
    hitCondition::Union{Missing,String} = missing
end

@dictable struct DisassembledInstruction
    address::String
    instructionBytes::Union{Missing,String} = missing
    instruction::String
    symbol::Union{Missing,String} = missing
    location::Union{Missing,Source} = missing
    line::Union{Missing,Int64} = missing
    column::Union{Missing,Int64} = missing
    endLine::Union{Missing,Int64} = missing
    endColumn::Union{Missing,Int64} = missing
end

@dictable struct ExceptionDetails
    message::Union{Missing,String} = missing
    typeName::Union{Missing,String} = missing
    fullTypeName::Union{Missing,String} = missing
    evaluateName::Union{Missing,String} = missing
    stackTrace::Union{Missing,String} = missing
    innerException::Union{Vector{ExceptionDetails}} = missing
end

@dictable struct ExceptionPathSegment
    negate::Union{Missing,Bool} = missing
    names::Vector{String} = String[]
end

@dictable struct ExceptionOptions
    path::Union{Missing,Vector{ExceptionPathSegment}} = missing
    breakMode::ExceptionBreakMode
end

@dictable struct FunctionBreakpoint
    name::String
    condition::Union{Missing,String} = missing
    hitCondition::Union{Missing,String} = missing
end

@dictable struct GotoTarget
    id::Int64
    label::String
    line::Int64
    column::Union{Missing,Int64} = missing
    endLine::Union{Missing,Int64} = missing
    endColumn::Union{Missing,Int64} = missing
    instructionPointerReference::Union{Missing,String} = missing
end

@dictable struct Message
    id::Int64
    format::String
    variables::Union{Missing,Dict{String,String}} = missing
    sendTelemetry::Union{Missing,Bool} = missing
    showUser::Union{Missing,Bool} = missing
    url::Union{Missing,String} = missing
    urlLabel::Union{Missing,String} = missing
end

@dictable struct Module
    id::Union{Int64,String}
    name::String
    path::Union{Missing,String} = missing
    isOptimized::Union{Missing,Bool} = missing
    isUserCode::Union{Missing,Bool} = missing
    version::Union{Missing,String} = missing
    symbolStatus::Union{Missing,String} = missing
    symbolFilePath::Union{Missing,String} = missing
    dateTimeStamp::Union{Missing,String} = missing
    addressRange::Union{Missing,String} = missing
end

@dictable struct ModulesViewDescriptor
    columns::Vector{ColumnDescriptor} = ColumnDescriptor[]
end

@dictable struct Scope
    name::String
    presentationHint::Union{Missing,ScopePresentationHint} = missing
    variablesReference::Int64
    namedVariables::Union{Missing,Int64} = missing
    indexedVariables::Union{Missing,Int64} = missing
    expensive::Bool = false
    source::Union{Missing,Source} = missing
    line::Union{Missing,Int64} = missing
    column::Union{Missing,Int64} = missing
    endLine::Union{Missing,Int64} = missing
    endColum::Union{Missing,Int64} = missing
end

@dictable struct SourceBreakpoint
    line::Int64
    column::Union{Missing,Int64} = missing
    condition::Union{Missing,String} = missing
    hitCondition::Union{Missing,String} = missing
    logMessage::Union{Missing,String} = missing
end

@dictable struct StackFrame
    id::Int64
    name::String
    source::Union{Missing,Source} = missing
    line::Int64
    column::Int64
    endLine::Union{Missing,Int64} = missing
    endColum::Union{Missing,Int64} = missing
    instructionPointerReference::Union{Missing,String} = missing
    moduleId::Union{Missing,Int64,String} = missing
    presentationHint::Union{Missing,StackFramePresentationHint} = missing
end

@dictable struct StackFrameFormat
    parameters::Union{Missing,Bool} = missing
    parameterTypes::Union{Missing,Bool} = missing
    parameterNames::Union{Missing,Bool} = missing
    parameterValues::Union{Missing,Bool} = missing
    line::Union{Missing,Bool} = missing
    mod::Union{Missing,Bool} = missing
    includeAll::Union{Missing,Bool} = missing
end :module => :mod

@dictable struct StepInTarget
    id::Int64
    label::String
end

@dictable struct Thread
    id::Int64
    name::String
end

@dictable struct ValueFormat
    hex::Union{Missing,Bool} = missing
end

@dictable struct VariablePresentationHint
    kind::Union{Missing,VariablePresentationHintKind} = missing
    attributes::Union{Missing,Vector{VariablePresentationHintAttribute}} = missing
    visibility::Union{Missing,VariablePresentationHintVisibility} = missing
end

@dictable struct Variable
    name::String
    value::String
    type::Union{Missing,String} = missing
    presentatonHint::Union{Missing,VariablePresentationHint} = missing
    evaluateName::Union{Missing,String} = missing
    variablesReference::Int64
    namedVariables::Union{Missing,Int64} = missing
    indexedVariables::Union{Missing,Int64} = missing
    memoryReference::Union{Missing,String} = missing
end
