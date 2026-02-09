$version: "2"

namespace com.anthropic.mcp

use alloy#discriminated
use alloy#jsonUnknown
use alloy#openEnum
use alloy#untagged

/// Model Context Protocol Specification
/// This Smithy model represents the MCP JSON Schema with 145 definitions
// ===== Common Maps =====
/// Map for metadata fields that can contain arbitrary JSON
map MetadataMap {
    key: String
    value: Document
}

// ===== String Type Aliases =====
/// A uniquely identifying ID for a request in JSON-RPC
@untagged
union RequestId {
    stringValue: String
    intValue: Integer
}

/// An opaque token used to represent a cursor for pagination
string Cursor

/// An opaque token for progress notifications
@untagged
union ProgressToken {
    stringValue: String
    intValue: Integer
}

// ===== Enums =====
/// The sender or recipient of messages and data in a conversation
enum Role {
    ASSISTANT = "assistant"
    USER = "user"
}

/// The severity of a log message
/// These map to syslog message severities, as specified in RFC-5424
@openEnum
enum LoggingLevel {
    ALERT = "alert"
    CRITICAL = "critical"
    DEBUG = "debug"
    EMERGENCY = "emergency"
    ERROR = "error"
    INFO = "info"
    NOTICE = "notice"
    WARNING = "warning"
}

/// The status of a task
enum TaskStatus {
    CANCELLED = "cancelled"
    COMPLETED = "completed"
    FAILED = "failed"
    INPUT_REQUIRED = "input_required"
    WORKING = "working"
}

// ===== Annotations =====
/// Optional annotations for the client
structure Annotations {
    /// Describes who the intended audience of this object or data is
    audience: RoleList

    /// The moment the resource was last modified, as an ISO 8601 formatted string
    lastModified: String

    /// Describes how important this data is for operating the server (0-1)
    @range(min: 0, max: 1)
    priority: Double
}

list RoleList {
    member: Role
}

// ===== Base Metadata =====
/// Base interface for metadata with name (identifier) and title (display name)
@mixin
structure BaseMetadata {
    /// Intended for programmatic or logical use
    @required
    name: String

    /// Intended for UI and end-user contexts
    title: String
}

/// Base interface to add icons property
@mixin
structure Icons {
    /// Optional set of sized icons that the client can display
    icons: IconList
}

list IconList {
    member: Icon
}

/// An optionally-sized icon that can be displayed in a user interface
structure Icon {
    /// A standard URI pointing to an icon resource
    @required
    src: String

    /// Optional MIME type override
    mimeType: String

    /// Optional array of strings that specify sizes
    sizes: StringList

    /// Optional theme specifier (light or dark)
    theme: String
}

list StringList {
    member: String
}

// ===== Content Blocks =====
/// Text provided to or from an LLM
structure TextContent {
    @required
    text: String

    @jsonUnknown
    _meta: MetadataMap

    annotations: Annotations
}

/// An image provided to or from an LLM
structure ImageContent {
    @required
    @length(min: 1)
    data: String

    @required
    mimeType: String

    @jsonUnknown
    _meta: MetadataMap

    annotations: Annotations
}

/// Audio provided to or from an LLM
structure AudioContent {
    @required
    @length(min: 1)
    data: String

    @required
    mimeType: String

    @jsonUnknown
    _meta: MetadataMap

    annotations: Annotations
}

/// A resource link in a prompt or tool call result
structure ResourceLink with [BaseMetadata, Icons] {
    @required
    uri: String

    description: String

    mimeType: String

    size: Integer

    @jsonUnknown
    _meta: MetadataMap

    annotations: Annotations
}

/// The contents of a resource, embedded into a prompt or tool call result
structure EmbeddedResource {
    @required
    resource: ResourceContentsUnion

    @jsonUnknown
    _meta: MetadataMap

    annotations: Annotations
}

/// Union of text and blob resource contents
@untagged
union ResourceContentsUnion {
    text: TextResourceContents
    blob: BlobResourceContents
}

/// Text resource contents
structure TextResourceContents {
    @required
    uri: String

    @required
    text: String

    mimeType: String

    @jsonUnknown
    _meta: MetadataMap
}

/// Blob resource contents
structure BlobResourceContents {
    @required
    uri: String

    @required
    @length(min: 1)
    blob: String

    mimeType: String

    @jsonUnknown
    _meta: MetadataMap
}

/// A discriminated union of content block types
@discriminated("type")
union ContentBlock {
    text: TextContent
    image: ImageContent
    audio: AudioContent
    resource_link: ResourceLink
    resource: EmbeddedResource
}

list ContentBlockList {
    member: ContentBlock
}

// ===== Tool Content Types =====
/// A request from the assistant to call a tool
structure ToolUseContent {
    @required
    id: String

    @required
    name: String

    @required
    input: Document

    @jsonUnknown
    _meta: MetadataMap
}

/// The result of a tool use
structure ToolResultContent {
    @required
    toolUseId: String

    @required
    content: ContentBlockList

    isError: Boolean

    structuredContent: Document

    @jsonUnknown
    _meta: MetadataMap
}

/// Content block for sampling messages
@discriminated("type")
union SamplingMessageContentBlock {
    text: TextContent
    image: ImageContent
    audio: AudioContent
    tool_use: ToolUseContent
    tool_result: ToolResultContent
}

list SamplingMessageContentBlockList {
    member: SamplingMessageContentBlock
}

/// Flexible content type for sampling messages
@untagged
union SamplingMessageContent {
    single: SamplingMessageContentBlock
    multiple: SamplingMessageContentBlockList
}

/// Describes a message issued to or received from an LLM API
structure SamplingMessage {
    @required
    role: Role

    @required
    content: SamplingMessageContent

    @jsonUnknown
    _meta: MetadataMap
}

list SamplingMessageList {
    member: SamplingMessage
}

// ===== Implementation Info =====
/// Describes the MCP implementation
structure Implementation with [BaseMetadata, Icons] {
    @required
    version: String

    description: String

    websiteUrl: String
}

// ===== Tool Definitions =====
/// Additional properties describing a Tool to clients
structure ToolAnnotations {
    /// A human-readable title for the tool
    title: String

    /// If true, the tool does not modify its environment
    readOnlyHint: Boolean

    /// If true, the tool may perform destructive updates
    destructiveHint: Boolean

    /// If true, calling repeatedly has no additional effect
    idempotentHint: Boolean

    /// If true, this tool may interact with an "open world"
    openWorldHint: Boolean
}

/// Execution-related properties for a tool
structure ToolExecution {
    /// Indicates whether this tool supports task-augmented execution
    taskSupport: String
}

/// Definition for a tool the client can call
structure Tool with [BaseMetadata, Icons] {
    @required
    inputSchema: ToolSchema

    outputSchema: ToolSchema

    description: String

    annotations: ToolAnnotations

    execution: ToolExecution

    @jsonUnknown
    _meta: MetadataMap
}

list ToolList {
    member: Tool
}

/// JSON Schema for tool parameters
structure ToolSchema {
    @required
    type: String = "object"

    properties: Document

    required: StringList

    @jsonName("$schema")
    schema: String
}

/// Controls tool selection behavior for sampling requests
structure ToolChoice {
    /// Controls the tool use ability of the model
    mode: String
}

// ===== Prompt Definitions =====
/// A prompt or prompt template that the server offers
structure Prompt with [BaseMetadata, Icons] {
    description: String

    arguments: PromptArgumentList

    @jsonUnknown
    _meta: MetadataMap
}

list PromptList {
    member: Prompt
}

/// An argument for a prompt
structure PromptArgument {
    @required
    name: String

    description: String

    required: Boolean
}

list PromptArgumentList {
    member: PromptArgument
}

/// A message from a prompt
structure PromptMessage {
    @required
    role: Role

    @required
    content: PromptMessageContent

    @jsonUnknown
    _meta: MetadataMap
}

list PromptMessageList {
    member: PromptMessage
}

/// Content for a prompt message
@untagged
union PromptMessageContent {
    single: ContentBlock
    multiple: ContentBlockList
}

/// A reference to a prompt
structure PromptReference {
    @required
    type: String = "ref/prompt"

    @required
    name: String
}

// ===== Resource Definitions =====
/// A known resource that the server is capable of reading
structure Resource with [BaseMetadata, Icons] {
    @required
    uri: String

    description: String

    mimeType: String

    size: Integer

    annotations: Annotations

    @jsonUnknown
    _meta: MetadataMap
}

list ResourceList {
    member: Resource
}

/// The contents of a specific resource or sub-resource
structure ResourceContents {
    @required
    uri: String

    mimeType: String

    @jsonUnknown
    _meta: MetadataMap
}

/// A template description for resources available on the server
structure ResourceTemplate with [BaseMetadata, Icons] {
    @required
    uriTemplate: String

    description: String

    mimeType: String

    annotations: Annotations

    @jsonUnknown
    _meta: MetadataMap
}

list ResourceTemplateList {
    member: ResourceTemplate
}

/// A reference to a resource or resource template definition
structure ResourceTemplateReference {
    @required
    type: String = "ref/resource"

    @required
    uri: String
}

// ===== Root Definitions =====
/// Represents a root directory or file that the server can operate on
structure Root {
    @required
    uri: String

    name: String

    @jsonUnknown
    _meta: MetadataMap
}

list RootList {
    member: Root
}

// ===== Task Definitions =====
/// Metadata for augmenting a request with task execution
structure TaskMetadata {
    /// Requested duration in milliseconds to retain task from creation
    ttl: Integer
}

/// Data associated with a task
@mixin
structure Task {
    @required
    taskId: String

    @required
    status: TaskStatus

    @required
    createdAt: String

    @required
    lastUpdatedAt: String

    @required
    ttl: Integer

    statusMessage: String

    pollInterval: Integer
}

/// Concrete type for Task (when used as a field type)
structure TaskValue with [Task] {}

/// Metadata for associating messages with a task
structure RelatedTaskMetadata {
    @required
    taskId: String
}

// ===== Model Preferences =====
/// Hints to use for model selection
structure ModelHint {
    /// A hint for a model name
    name: String
}

list ModelHintList {
    member: ModelHint
}

/// Model selection preferences
structure ModelPreferences {
    /// Optional hints to use for model selection
    hints: ModelHintList

    /// How much to prioritize cost (0-1)
    @range(min: 0, max: 1)
    costPriority: Double

    /// How much to prioritize speed (0-1)
    @range(min: 0, max: 1)
    speedPriority: Double

    /// How much to prioritize intelligence (0-1)
    @range(min: 0, max: 1)
    intelligencePriority: Double
}

// ===== Capabilities =====
/// Capabilities a client may support
structure ClientCapabilities {
    /// Present if the client supports elicitation from the server
    elicitation: ElicitationCapability

    /// Present if the client supports listing roots
    roots: RootsCapability

    /// Present if the client supports sampling from an LLM
    sampling: SamplingCapability

    /// Present if the client supports task-augmented requests
    tasks: TasksClientCapability

    /// Experimental, non-standard capabilities
    @jsonUnknown
    experimental: MetadataMap
}

structure ElicitationCapability {
    form: Document
    url: Document
}

structure RootsCapability {
    /// Whether the client supports notifications for changes to the roots list
    listChanged: Boolean
}

structure SamplingCapability {
    /// Whether the client supports context inclusion
    context: Document

    /// Whether the client supports tool use
    tools: Document
}

structure TasksClientCapability {
    /// Whether this client supports tasks/cancel
    cancel: Document

    /// Whether this client supports tasks/list
    list: Document

    /// Specifies which request types can be augmented with tasks
    requests: TaskRequestsCapability
}

structure TaskRequestsCapability {
    /// Task support for elicitation-related requests
    elicitation: ElicitationTaskCapability

    /// Task support for sampling-related requests
    sampling: SamplingTaskCapability
}

structure ElicitationTaskCapability {
    /// Whether the client supports task-augmented elicitation/create requests
    create: Document
}

structure SamplingTaskCapability {
    /// Whether the client supports task-augmented sampling/createMessage requests
    createMessage: Document
}

/// Capabilities that a server may support
structure ServerCapabilities {
    /// Present if the server supports argument autocompletion suggestions
    completions: Document

    /// Present if the server supports sending log messages to the client
    logging: Document

    /// Present if the server offers any prompt templates
    prompts: PromptsCapability

    /// Present if the server offers any resources to read
    resources: ResourcesCapability

    /// Present if the server offers any tools to call
    tools: ToolsCapability

    /// Present if the server supports task-augmented requests
    tasks: TasksServerCapability

    /// Experimental, non-standard capabilities
    @jsonUnknown
    experimental: MetadataMap
}

structure PromptsCapability {
    /// Whether this server supports notifications for changes to the prompt list
    listChanged: Boolean
}

structure ResourcesCapability {
    /// Whether this server supports notifications for changes to the resource list
    listChanged: Boolean

    /// Whether this server supports subscribing to resource updates
    subscribe: Boolean
}

structure ToolsCapability {
    /// Whether this server supports notifications for changes to the tool list
    listChanged: Boolean
}

structure TasksServerCapability {
    /// Whether this server supports tasks/cancel
    cancel: Document

    /// Whether this server supports tasks/list
    list: Document

    /// Specifies which request types can be augmented with tasks
    requests: TaskRequestsServerCapability
}

structure TaskRequestsServerCapability {
    /// Task support for tool-related requests
    tools: ToolsTaskCapability
}

structure ToolsTaskCapability {
    /// Whether the server supports task-augmented tools/call requests
    call: Document
}

// ===== JSON-RPC Base Types =====
/// Base JSON-RPC message
@mixin
structure JSONRPCMessage {
    @required
    jsonrpc: String = "2.0"
}

/// Base for JSON-RPC requests
structure JSONRPCRequest with [JSONRPCMessage] {
    @required
    id: RequestId

    @required
    method: String

    params: Document
}

/// Base for JSON-RPC notifications
structure JSONRPCNotification with [JSONRPCMessage] {
    @required
    method: String

    params: Document
}

/// Base for JSON-RPC responses
@mixin
structure JSONRPCResponse with [JSONRPCMessage] {
    @required
    id: RequestId
}

/// Successful JSON-RPC response
structure JSONRPCResultResponse with [JSONRPCResponse] {
    @required
    result: Document
}

/// Error JSON-RPC response
structure JSONRPCErrorResponse with [JSONRPCResponse] {
    @required
    error: Error
}

/// JSON-RPC error
structure Error {
    @required
    code: Integer

    @required
    message: String

    data: Document
}

// ===== Request/Response Params =====
/// Common params for any request
structure RequestParams {
    @jsonUnknown
    _meta: MetadataMap
}

/// Common params for notifications
@mixin
structure NotificationParams {
    @jsonUnknown
    _meta: MetadataMap
}

/// Concrete type for notification params (when used as a field type)
structure NotificationParamsValue with [NotificationParams] {}

/// Common params for any task-augmented request
structure TaskAugmentedRequestParams {
    /// If specified, the caller is requesting task-augmented execution
    task: TaskMetadata

    @jsonUnknown
    _meta: MetadataMap
}

/// Common params for paginated requests
structure PaginatedRequestParams {
    cursor: Cursor

    @jsonUnknown
    _meta: MetadataMap
}

/// Common result structure
@mixin
structure Result {
    @jsonUnknown
    _meta: MetadataMap
}

/// Concrete type for Result (when used as a field type)
structure ResultValue with [Result] {}

/// Empty result
structure EmptyResult with [Result] {}

/// Paginated result structure
@mixin
structure PaginatedResult {
    nextCursor: Cursor

    @jsonUnknown
    _meta: MetadataMap
}

// ===== Initialize =====
/// Initialize request from client to server
structure InitializeRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "initialize"

    @required
    params: InitializeRequestParams
}

structure InitializeRequestParams {
    @required
    protocolVersion: String

    @required
    capabilities: ClientCapabilities

    @required
    clientInfo: Implementation

    @jsonUnknown
    _meta: MetadataMap
}

/// Initialize response from server to client
structure InitializeResult with [Result] {
    @required
    protocolVersion: String

    @required
    capabilities: ServerCapabilities

    @required
    serverInfo: Implementation

    instructions: String
}

/// Initialized notification from client to server
structure InitializedNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/initialized"

    params: NotificationParamsValue
}

// ===== Ping =====
/// Ping request (can be sent by either side)
structure PingRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "ping"
}

// ===== Resources =====
/// List resources request
structure ListResourcesRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "resources/list"

    params: PaginatedRequestParams
}

structure ListResourcesResult with [Result, PaginatedResult] {
    @required
    resources: ResourceList
}

/// List resource templates request
structure ListResourceTemplatesRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "resources/templates/list"

    params: PaginatedRequestParams
}

structure ListResourceTemplatesResult with [Result, PaginatedResult] {
    @required
    resourceTemplates: ResourceTemplateList
}

/// Read resource request
structure ReadResourceRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "resources/read"

    @required
    params: ReadResourceRequestParams
}

structure ReadResourceRequestParams with [ResourceRequestParams] {}

@mixin
structure ResourceRequestParams {
    @required
    uri: String

    @jsonUnknown
    _meta: MetadataMap
}

structure ReadResourceResult with [Result] {
    @required
    contents: ResourceContentsList
}

list ResourceContentsList {
    member: ResourceContentsUnion
}

/// Subscribe to resource updates
structure SubscribeRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "resources/subscribe"

    @required
    params: SubscribeRequestParams
}

structure SubscribeRequestParams {
    @required
    uri: String

    @jsonUnknown
    _meta: MetadataMap
}

/// Unsubscribe from resource updates
structure UnsubscribeRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "resources/unsubscribe"

    @required
    params: UnsubscribeRequestParams
}

structure UnsubscribeRequestParams {
    @required
    uri: String

    @jsonUnknown
    _meta: MetadataMap
}

/// Resource list changed notification
structure ResourceListChangedNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/resources/list_changed"

    params: NotificationParamsValue
}

/// Resource updated notification
structure ResourceUpdatedNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/resources/updated"

    @required
    params: ResourceUpdatedNotificationParams
}

structure ResourceUpdatedNotificationParams {
    @required
    uri: String

    @jsonUnknown
    _meta: MetadataMap
}

// ===== Prompts =====
/// List prompts request
structure ListPromptsRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "prompts/list"

    params: PaginatedRequestParams
}

structure ListPromptsResult with [Result, PaginatedResult] {
    @required
    prompts: PromptList
}

/// Get prompt request
structure GetPromptRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "prompts/get"

    @required
    params: GetPromptRequestParams
}

structure GetPromptRequestParams {
    @required
    name: String

    arguments: StringMap

    @jsonUnknown
    _meta: MetadataMap
}

map StringMap {
    key: String
    value: String
}

structure GetPromptResult with [Result] {
    @required
    messages: PromptMessageList

    description: String
}

/// Prompt list changed notification
structure PromptListChangedNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/prompts/list_changed"

    params: NotificationParamsValue
}

// ===== Tools =====
/// List tools request
structure ListToolsRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "tools/list"

    params: PaginatedRequestParams
}

structure ListToolsResult with [Result, PaginatedResult] {
    @required
    tools: ToolList
}

/// Call tool request
structure CallToolRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "tools/call"

    @required
    params: CallToolRequestParams
}

structure CallToolRequestParams {
    @required
    name: String

    arguments: Document

    task: TaskMetadata

    @jsonUnknown
    _meta: MetadataMap
}

structure CallToolResult with [Result] {
    @required
    content: ContentBlockList

    isError: Boolean

    structuredContent: Document
}

/// Tool list changed notification
structure ToolListChangedNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/tools/list_changed"

    params: NotificationParamsValue
}

// ===== Tasks =====
/// Get task request
structure GetTaskRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "tasks/get"

    @required
    params: TaskIdParams
}

structure TaskIdParams {
    @required
    taskId: String
}

structure GetTaskResult with [Result, Task] {}

/// Get task payload request
structure GetTaskPayloadRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "tasks/result"

    @required
    params: TaskIdParams
}

structure GetTaskPayloadResult with [Result] {
    payload: Document
}

/// Cancel task request
structure CancelTaskRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "tasks/cancel"

    @required
    params: TaskIdParams
}

structure CancelTaskResult with [Result, Task] {}

/// List tasks request
structure ListTasksRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "tasks/list"

    params: PaginatedRequestParams
}

structure ListTasksResult with [Result, PaginatedResult] {
    @required
    tasks: TaskList
}

list TaskList {
    member: TaskValue
}

/// Create task result
structure CreateTaskResult with [Result] {
    @required
    task: TaskValue
}

/// Task status notification
structure TaskStatusNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/tasks/status"

    @required
    params: TaskStatusNotificationParams
}

structure TaskStatusNotificationParams with [NotificationParams, Task] {}

// ===== Logging =====
/// Set logging level request
structure SetLevelRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "logging/setLevel"

    @required
    params: SetLevelRequestParams
}

structure SetLevelRequestParams {
    @required
    level: LoggingLevel

    @jsonUnknown
    _meta: MetadataMap
}

/// Logging message notification
structure LoggingMessageNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/message"

    @required
    params: LoggingMessageNotificationParams
}

structure LoggingMessageNotificationParams {
    @required
    level: LoggingLevel

    @required
    logger: String

    @required
    data: Document

    @jsonUnknown
    _meta: MetadataMap
}

// ===== Progress =====
/// Progress notification
structure ProgressNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/progress"

    @required
    params: ProgressNotificationParams
}

structure ProgressNotificationParams {
    @required
    progressToken: ProgressToken

    @required
    progress: Double

    total: Double

    @jsonUnknown
    _meta: MetadataMap
}

// ===== Cancelled =====
/// Cancelled notification
structure CancelledNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/cancelled"

    @required
    params: CancelledNotificationParams
}

structure CancelledNotificationParams {
    requestId: RequestId

    reason: String

    @jsonUnknown
    _meta: MetadataMap
}

// ===== Sampling =====
/// Create message request (from server to client)
structure CreateMessageRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "sampling/createMessage"

    @required
    params: CreateMessageRequestParams
}

structure CreateMessageRequestParams {
    @required
    messages: SamplingMessageList

    @required
    maxTokens: Integer

    modelPreferences: ModelPreferences

    systemPrompt: String

    includeContext: String

    temperature: Double

    stopSequences: StringList

    tools: ToolList

    toolChoice: ToolChoice

    task: TaskMetadata

    metadata: Document

    @jsonUnknown
    _meta: MetadataMap
}

structure CreateMessageResult with [Result] {
    @required
    role: Role

    @required
    content: SamplingMessageContent

    @required
    model: String

    stopReason: String
}

// ===== Roots =====
/// List roots request
structure ListRootsRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "roots/list"

    params: PaginatedRequestParams
}

structure ListRootsResult with [Result, PaginatedResult] {
    @required
    roots: RootList
}

/// Roots list changed notification
structure RootsListChangedNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/roots/list_changed"

    params: NotificationParamsValue
}

// ===== Completion =====
/// Completion request
structure CompleteRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "completion/complete"

    @required
    params: CompleteRequestParams
}

structure CompleteRequestParams {
    @required
    ref: CompleteRefUnion

    @required
    argument: CompleteArgument

    context: CompleteContext

    @jsonUnknown
    _meta: MetadataMap
}

@untagged
union CompleteRefUnion {
    prompt: PromptReference
    resource: ResourceTemplateReference
}

structure CompleteArgument {
    @required
    name: String

    @required
    value: String
}

structure CompleteContext {
    arguments: StringMap
}

structure CompleteResult with [Result] {
    @required
    completion: Completion
}

structure Completion {
    @required
    values: StringList

    total: Integer

    hasMore: Boolean
}

// ===== Elicitation =====
/// Elicitation request from server to client
structure ElicitRequest {
    @required
    id: RequestId

    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "elicitation/create"

    @required
    params: ElicitRequestParams
}

@untagged
union ElicitRequestParams {
    url: ElicitRequestURLParams
    form: ElicitRequestFormParams
}

structure ElicitRequestURLParams {
    @required
    mode: String = "url"

    @required
    elicitationId: String

    @required
    url: String

    @required
    message: String

    task: TaskMetadata

    @jsonUnknown
    _meta: MetadataMap
}

structure ElicitRequestFormParams {
    @required
    mode: String = "form"

    @required
    message: String

    @required
    requestedSchema: ElicitFormSchema

    task: TaskMetadata

    @jsonUnknown
    _meta: MetadataMap
}

structure ElicitFormSchema {
    @required
    type: String = "object"

    @required
    properties: Document

    required: StringList

    @jsonName("$schema")
    schema: String
}

structure ElicitResult with [Result] {
    @required
    action: String

    content: Document
}

/// Elicitation complete notification
structure ElicitationCompleteNotification {
    @required
    jsonrpc: String = "2.0"

    @required
    method: String = "notifications/elicitation/complete"

    @required
    params: ElicitationCompleteParams
}

structure ElicitationCompleteParams {
    @required
    elicitationId: String
}

/// URL elicitation required error
structure URLElicitationRequiredError {
    @required
    jsonrpc: String = "2.0"

    id: RequestId

    @required
    error: ElicitationError
}

structure ElicitationError {
    @required
    code: Integer = -32042

    @required
    message: String

    @required
    data: ElicitationErrorData
}

structure ElicitationErrorData {
    @required
    elicitations: ElicitRequestURLParamsList
}

list ElicitRequestURLParamsList {
    member: ElicitRequestURLParams
}

// ===== Schema Definitions =====
/// Restricted schema definitions for primitive types
@untagged
union PrimitiveSchemaDefinition {
    string: StringSchema
    number: NumberSchema
    boolean: BooleanSchema
    untitledSingleEnum: UntitledSingleSelectEnumSchema
    titledSingleEnum: TitledSingleSelectEnumSchema
    untitledMultiEnum: UntitledMultiSelectEnumSchema
    titledMultiEnum: TitledMultiSelectEnumSchema
    legacyEnum: LegacyTitledEnumSchema
}

structure StringSchema {
    @required
    type: String = "string"

    title: String

    description: String

    default: String

    format: String

    minLength: Integer

    maxLength: Integer
}

structure NumberSchema {
    @required
    type: String

    title: String

    description: String

    default: Integer

    minimum: Integer

    maximum: Integer
}

structure BooleanSchema {
    @required
    type: String = "boolean"

    title: String

    description: String

    default: Boolean
}

structure UntitledSingleSelectEnumSchema {
    @required
    type: String = "string"

    @required
    enum: StringList

    title: String

    description: String

    default: String
}

structure TitledSingleSelectEnumSchema {
    @required
    type: String = "string"

    @required
    oneOf: TitledEnumOptionList

    title: String

    description: String

    default: String
}

list TitledEnumOptionList {
    member: TitledEnumOption
}

structure TitledEnumOption {
    @required
    const: String

    @required
    title: String
}

structure UntitledMultiSelectEnumSchema {
    @required
    type: String = "array"

    @required
    items: UntitledEnumItems

    title: String

    description: String

    default: StringList

    minItems: Integer

    maxItems: Integer
}

structure UntitledEnumItems {
    @required
    type: String = "string"

    @required
    enum: StringList
}

structure TitledMultiSelectEnumSchema {
    @required
    type: String = "array"

    @required
    items: TitledEnumItems

    title: String

    description: String

    default: StringList

    minItems: Integer

    maxItems: Integer
}

structure TitledEnumItems {
    @required
    anyOf: TitledEnumOptionList
}

/// Legacy enum schema (deprecated)
structure LegacyTitledEnumSchema {
    @required
    type: String = "string"

    @required
    enum: StringList

    /// (Legacy) Display names for enum values
    enumNames: StringList

    title: String

    description: String

    default: String
}

/// Single select enum union
@untagged
union SingleSelectEnumSchema {
    untitled: UntitledSingleSelectEnumSchema
    titled: TitledSingleSelectEnumSchema
}

/// Multi select enum union
@untagged
union MultiSelectEnumSchema {
    untitled: UntitledMultiSelectEnumSchema
    titled: TitledMultiSelectEnumSchema
}

/// General enum schema union
@untagged
union EnumSchema {
    untitledSingle: UntitledSingleSelectEnumSchema
    titledSingle: TitledSingleSelectEnumSchema
    untitledMulti: UntitledMultiSelectEnumSchema
    titledMulti: TitledMultiSelectEnumSchema
    legacy: LegacyTitledEnumSchema
}

// ===== Union Types for Requests/Responses =====
/// Union of all client requests
@untagged
union ClientRequest {
    initialize: InitializeRequest
    ping: PingRequest
    listResources: ListResourcesRequest
    listResourceTemplates: ListResourceTemplatesRequest
    readResource: ReadResourceRequest
    subscribe: SubscribeRequest
    unsubscribe: UnsubscribeRequest
    listPrompts: ListPromptsRequest
    getPrompt: GetPromptRequest
    listTools: ListToolsRequest
    callTool: CallToolRequest
    getTask: GetTaskRequest
    getTaskPayload: GetTaskPayloadRequest
    cancelTask: CancelTaskRequest
    listTasks: ListTasksRequest
    setLevel: SetLevelRequest
    complete: CompleteRequest
}

/// Union of all server requests
@untagged
union ServerRequest {
    ping: PingRequest
    getTask: GetTaskRequest
    getTaskPayload: GetTaskPayloadRequest
    cancelTask: CancelTaskRequest
    listTasks: ListTasksRequest
    createMessage: CreateMessageRequest
    listRoots: ListRootsRequest
    elicit: ElicitRequest
}

/// Union of all client notifications
@untagged
union ClientNotification {
    cancelled: CancelledNotification
    initialized: InitializedNotification
    progress: ProgressNotification
    taskStatus: TaskStatusNotification
    rootsListChanged: RootsListChangedNotification
}

/// Union of all server notifications
@untagged
union ServerNotification {
    cancelled: CancelledNotification
    progress: ProgressNotification
    resourceListChanged: ResourceListChangedNotification
    resourceUpdated: ResourceUpdatedNotification
    promptListChanged: PromptListChangedNotification
    toolListChanged: ToolListChangedNotification
    taskStatus: TaskStatusNotification
    loggingMessage: LoggingMessageNotification
    elicitationComplete: ElicitationCompleteNotification
}

/// Union of all client results
@untagged
union ClientResult {
    empty: ResultValue
    getTask: GetTaskResult
    getTaskPayload: GetTaskPayloadResult
    cancelTask: CancelTaskResult
    listTasks: ListTasksResult
    createMessage: CreateMessageResult
    listRoots: ListRootsResult
    elicit: ElicitResult
}

/// Union of all server results
@untagged
union ServerResult {
    empty: ResultValue
    initialize: InitializeResult
    listResources: ListResourcesResult
    listResourceTemplates: ListResourceTemplatesResult
    readResource: ReadResourceResult
    listPrompts: ListPromptsResult
    getPrompt: GetPromptResult
    listTools: ListToolsResult
    callTool: CallToolResult
    getTask: GetTaskResult
    getTaskPayload: GetTaskPayloadResult
    cancelTask: CancelTaskResult
    listTasks: ListTasksResult
    complete: CompleteResult
}

/// General request union
@untagged
union Request {
    method: String
    params: Document
}

/// General notification union
@untagged
union Notification {
    method: String
    params: Document
}

/// Paginated request (mixin pattern)
structure PaginatedRequest {
    params: PaginatedRequestParams
}
