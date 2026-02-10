$version: "2"

namespace smithy4smcptraits

use jsonrpclib#jsonRpc
use jsonrpclib#jsonRpcPayload
use jsonrpclib#jsonRpcRequest
use modelcontextprotocol#CallToolRequestParams
use modelcontextprotocol#CallToolResult
use modelcontextprotocol#ElicitRequestParams
use modelcontextprotocol#ElicitResult
use modelcontextprotocol#InitializeRequestParams
use modelcontextprotocol#InitializeResult
use modelcontextprotocol#ListToolsResult
use modelcontextprotocol#PaginatedRequestParams

@protocolDefinition(
    traits: [mcpTool]
)
@trait
@traitValidators({
    AllOpsAreTools: { selector: "~> operation:not([trait|smithy4smcptraits#mcpTool])", message: "All operations of MCP services must be tools" }
})
structure mcpServerDefinition {}

@protocolDefinition(
    traits: [mcpElicitation]
)
@trait
@traitValidators({
    AllOpsAreElicitations: { selector: "~> operation:not([trait|smithy4smcptraits#mcpElicitation])", message: "All operations of MCP services must be elicications" }
})
structure mcpClientDefinition {}

@trait(selector: "service[trait|smithy4smcptraits#mcpServerDefinition] ~>")
structure mcpTool {
    /// Optional tool name. If not provided, the operation name will be used as the tool name.
    name: String
}

// inputs of operations with this trait MUST NOT have any members that aren't "message"
@trait
@traitValidators({
    OnlyMessageMember: { selector: "operation -[input]-> > member:not([id|member=message])", message: "Elicitation operations can only have a single required string member named 'message'." }
})
structure mcpElicitation {}

@jsonRpc
service McpServerApi {
    operations: [
        Initialize
        ListTools
        CallTool
        Ping
    ]
}

@jsonRpc
service McpClientApi {
    operations: [
        Ping
        Elicitation
    ]
}

@jsonRpcRequest("elicitation/create")
operation Elicitation {
    input := {
        @jsonRpcPayload
        @required
        params: ElicitRequestParams
    }

    output: ElicitResult
}

@jsonRpcRequest("initialize")
operation Initialize {
    input: InitializeRequestParams
    output: InitializeResult
}

@jsonRpcRequest("tools/list")
operation ListTools {
    input: PaginatedRequestParams
    output: ListToolsResult
}

@jsonRpcRequest("tools/call")
operation CallTool {
    input: CallToolRequestParams
    output: CallToolResult
}

@jsonRpcRequest("ping")
operation Ping {}
