$version: "2"

namespace my.server

use smithy4smcptraits#mcpServerDefinition
use smithy4smcptraits#mcpTool

@mcpTool
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

@mcpServerDefinition
service MyServer {
    operations: [
        Adder
    ]
}
