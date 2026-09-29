import ArgumentParser
import Foundation

extension Command {
    struct DeployCommand: RunCommand {
        static let configuration = CommandConfiguration(
            commandName: "deploy",
            abstract: "Deploy your application"
        )

        @OptionGroup var options: Options

        @Flag(help: "Deploy existing build artifacts without rebuilding. Run build first for the same stage.")
        var skipBuild = false

        func invoke(with context: Context) async throws {
            let spinner = UI.spinner(label: "Deploying changes")
            do {
                let prepared = try await prepare(with: context, buildTargets: !skipBuild)
                try await prepared.client.invoke(
                    command: "up",
                    arguments: ["--skip-preview", "--yes"],
                    onEvent: { spinner.push($0.string()) }
                )
                let outputs = try await prepared.client.stackOutputs()
                spinner.stop()
                UI.writeWarnings(spinner.warnings)
                UI.writeOutputs(outputs)
            } catch {
                spinner.stop()
                throw error
            }
        }
    }
}
