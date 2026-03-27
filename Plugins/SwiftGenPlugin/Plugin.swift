//
// SwiftGenPlugin
// Copyright © 2022 SwiftGen
// MIT Licence
//

import Foundation
import PackagePlugin

@main
struct SwiftGenPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    let fileManager = FileManager.default

    // Possible paths where there may be a config file (root of package, target dir.)
    let configurations: [URL] = [context.package.directoryURL, URL(filePath: "\(target.directory)")]
      .map { $0.appending(path: "swiftgen.yml") }
      .filter { fileManager.fileExists(atPath: $0.path) }

    // Validate paths list
    guard validate(configurations: configurations, target: target) else {
      return []
    }

    // Clear the SwiftGen plugin's directory (in case of dangling files)
    fileManager.forceClean(directory: context.pluginWorkDirectoryURL)

    return try configurations.map { configuration in
      try .swiftgen(using: configuration, context: context, target: target)
    }
  }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftGenPlugin: XcodeBuildToolPlugin {
  func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
    let fileManager = FileManager.default

    // Possible paths where there may be a config file (root of package, target dir.)
    let configurations: [URL] = [context.xcodeProject.directoryURL]
      .map { $0.appending(path: "swiftgen.yml") }
      .filter { fileManager.fileExists(atPath: $0.path) }

    // Validate paths list
    guard validate(configurations: configurations, target: target) else {
      return []
    }

    // Clear the SwiftGen plugin's directory (in case of dangling files)
    fileManager.forceClean(directory: context.pluginWorkDirectoryURL)

    return try configurations.map { configuration in
      try .swiftgen(using: configuration, context: context, target: target)
    }
  }
}
#endif

// MARK: - Helpers

private extension SwiftGenPlugin {
  /// Validate the given list of configurations
  func validate(configurations: [URL], target: Target) -> Bool {
    guard !configurations.isEmpty else {
      Diagnostics.error("""
      No SwiftGen configurations found for target \(target.name). If you would like to generate sources for this \
      target include a `swiftgen.yml` in the target's source directory, or include a shared `swiftgen.yml` at the \
      package's root.
      """)
      return false
    }

    return true
  }

#if canImport(XcodeProjectPlugin)
  func validate(configurations: [URL], target: XcodeTarget) -> Bool {
    guard !configurations.isEmpty else {
      Diagnostics.error("""
        No SwiftGen configurations found for target \(target.displayName). If you would like to generate sources for this \
        target include a `swiftgen.yml` in the target's source directory, or include a shared `swiftgen.yml` at the \
        package's root.
        """)
      return false
    }

    return true
  }
#endif
}

private extension Command {
  static func swiftgen(using configuration: URL, context: PluginContext, target: Target) throws -> Command {
    .prebuildCommand(
      displayName: "SwiftGen BuildTool Plugin",
      executable: try context.tool(named: "swiftgen").url,
      arguments: [
        "config",
        "run",
        "--verbose",
        "--config", configuration.path
      ],
      environment: [
        "PROJECT_DIR": context.package.directoryURL.path,
        "TARGET_NAME": target.name,
        "PRODUCT_MODULE_NAME": target.moduleName,
        "DERIVED_SOURCES_DIR": context.pluginWorkDirectoryURL.path
      ],
      outputFilesDirectory: context.pluginWorkDirectoryURL
    )
  }

#if canImport(XcodeProjectPlugin)
  static func swiftgen(using configuration: URL, context: XcodePluginContext, target: XcodeTarget) throws -> Command {
    .prebuildCommand(
      displayName: "SwiftGen BuildTool Plugin",
      executable: try context.tool(named: "swiftgen").url,
      arguments: [
        "config",
        "run",
        "--verbose",
        "--config", configuration.path
      ],
      environment: [
        "PROJECT_DIR": context.xcodeProject.directoryURL.path,
        "TARGET_NAME": target.displayName,
        "DERIVED_SOURCES_DIR": context.pluginWorkDirectoryURL.path
      ],
      outputFilesDirectory: context.pluginWorkDirectoryURL
    )
  }
#endif
}

private extension FileManager {
  /// Re-create the given directory
  func forceClean(directory: URL) {
    try? removeItem(at: directory)
    try? createDirectory(at: directory, withIntermediateDirectories: false)
  }
}

extension Target {
  /// Try to access the underlying `moduleName` property
  /// Falls back to target's name
  var moduleName: String {
    switch self {
    case let target as SourceModuleTarget:
      return target.moduleName
    default:
      return ""
    }
  }
}
