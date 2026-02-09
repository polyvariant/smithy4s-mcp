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

@jsonRpc
service MyMcpServer {
    operations: [
        Initialize
        ListTools
        CallTool
    ]
}

// @protocolDefinition(
//     traits: [tool]
// )
// @trait
// structure mcp {}
// @trait
// structure tool {}
// @mcp
// service MyServer {
//     operations: [
//         Adder
//     ]
// }
// @tool
operation Adder {
    input := {
        @required
        a: Integer

        @required
        b: Integer
    }

    output := {
        @required
        result: Integer
    }
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
