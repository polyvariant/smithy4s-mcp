$version: "2"

namespace smithy4smcptraits

use jsonrpclib#jsonRpc
use jsonrpclib#jsonRpcRequest
use modelcontextprotocol#CallToolRequestParams
use modelcontextprotocol#CallToolResult
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

@trait
structure mcpTool {}

@jsonRpc
service McpServerApi {
    operations: [
        Initialize
        ListTools
        CallTool
    ]
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
