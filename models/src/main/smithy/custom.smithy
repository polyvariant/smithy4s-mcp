$version: "2"

namespace my.server

use smithy4smcptraits#mcpClientDefinition
use smithy4smcptraits#mcpElicitation
use smithy4smcptraits#mcpServerDefinition
use smithy4smcptraits#mcpTool

@mcpTool
@readonly
operation Adder {
    input := {
        @required
        a: Integer

        b: Integer
    }

    output := {
        @required
        result: Integer

        comment: String
    }
}

@mcpServerDefinition
service MyServer {
    operations: [
        Adder
    ]
}

@mcpClientDefinition
service MyClient {
    operations: [
        AskName
    ]
}

@mcpElicitation
@readonly
operation AskName {
    input := {
        @required
        message: String
    }

    output := {
        @required
        name: String
    }
}
