$version: "2"

namespace my.server

use com.anthropic.mcp#CallToolRequestParams
use com.anthropic.mcp#CallToolResult
use com.anthropic.mcp#InitializeRequestParams
use com.anthropic.mcp#InitializeResult
use com.anthropic.mcp#ListToolsResult
use com.anthropic.mcp#PaginatedRequestParams
use jsonrpclib#jsonRpc
use jsonrpclib#jsonRpcRequest

@tool
operation Adder {
    input := {
        @required
        a: Integer

        b: Integer
    }

    output := {
        @required
        result: Integer
    }
}

@jsonRpc
service MyMcpServer {
    operations: [
        Initialize
        ListTools
        CallTool
    ]
}

@protocolDefinition(
    traits: [tool]
)
@trait
@traitValidators({
    AllOpsAreTools: { selector: "~> operation:not([trait|my.server#tool])", message: "All operations of MCP services must be tools" }
})
structure mcp {}

@trait
structure tool {}

@mcp
service MyServer {
    operations: [
        Adder
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
