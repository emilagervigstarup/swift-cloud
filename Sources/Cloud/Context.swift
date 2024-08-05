import Foundation

public struct Context {
    public internal(set) var stage: String
}

extension Context {
    @TaskLocal public static var current: Context!
}

extension Context {
    public static let cloudDirectory = "\(FileManager.default.currentDirectoryPath)/.cloud"
}
