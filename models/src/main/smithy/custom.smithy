$version: "2"

namespace my.server

use smithy4smcptraits#mcpClientDefinition
use smithy4smcptraits#mcpElicitation
use smithy4smcptraits#mcpServerDefinition
use smithy4smcptraits#mcpTool

@mcpServerDefinition
service MyServer {
    operations: [
        Adder
        ListCharacters
    ]
}

@mcpClientDefinition
service MyClient {
    operations: [
        AskName
    ]
}

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

@mcpTool
@readonly
operation ListCharacters {
    output := {
        @required
        characters: Characters
    }
}

list Characters {
    member: Character
}

structure Character {
    @required
    name: Name

    @required
    type: CharacterType
}

string Name

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

        extras: Integer
    }
}

enum CharacterType {
    BAD
    GOOD
}
