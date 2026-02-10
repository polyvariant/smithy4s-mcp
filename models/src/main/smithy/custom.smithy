$version: "2"

namespace my.server

use jsonrpclib#jsonRpcPayload
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

@mcpServerDefinition
service GithubMcpServer {
    operations: [
        GetMe
        ListPullRequests
    ]
}

@mcpTool(name: "get_me")
operation GetMe {
    output := {
        @required
        login: String
    }
}

@mcpTool(name: "list_pull_requests")
operation ListPullRequests {
    input := {
        @required
        owner: String

        @required
        repo: String
    }

    output := {
        @jsonRpcPayload
        @required
        prs: PullRequests
    }
}

list PullRequests {
    member: PullRequest
}

structure PullRequest {
    @required
    title: String
}
