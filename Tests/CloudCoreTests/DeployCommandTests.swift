import Testing

@testable import CloudCore

@Suite("Deploy command")
struct DeployCommandTests {
    @Test("Normal deploy still builds by default")
    func buildsByDefault() throws {
        let command = try Command.DeployCommand.parse(["--stage", "development"])
        #expect(!command.skipBuild)
        #expect(command.options.stage == "development")
    }

    @Test("Skip-build preserves the explicitly selected stage")
    func skipBuild() throws {
        let command = try Command.DeployCommand.parse(["--stage", "production", "--skip-build"])
        #expect(command.skipBuild)
        #expect(command.options.stage == "production")
    }
}
