import Foundation
import Testing

@testable import CloudCore

@Suite("Resource option tests")
struct ResourceOptionsTests {
    struct TestProject: Project {
        func build() async throws -> Outputs { [:] }
    }

    @Test("ignoreChanges is emitted as Pulumi resource options")
    func ignoreChangesEncoding() throws {
        let context = Context(
            stage: "testing",
            project: TestProject(),
            package: .init(name: "test"),
            store: .init(),
            builder: .init()
        )
        let resource = Resource(
            name: "secret",
            type: "aws:secretsmanager/secret:Secret",
            properties: ["name": "example"],
            options: .protect().ignoreChanges([
                "forceOverwriteReplicaSecret",
                "recoveryWindowInDays",
            ]),
            context: context
        )

        let data = try JSONEncoder().encode(resource.pulumiProjectResources())
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encodedResource = try #require(json["testing-secret"] as? [String: Any])
        let options = try #require(encodedResource["options"] as? [String: Any])

        #expect(options["protect"] as? Bool == true)
        #expect(options["ignoreChanges"] as? [String] == [
            "forceOverwriteReplicaSecret",
            "recoveryWindowInDays",
        ])
    }
}
