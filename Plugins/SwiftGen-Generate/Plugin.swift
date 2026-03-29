//
// SwiftGenPlugin
// Copyright © 2022 SwiftGen
// MIT Licence
//

import Foundation
import PackagePlugin

@main
struct SwiftGenPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let swiftgen = try context.tool(named: "swiftgen")
    let fileManager = FileManager.default

    let configuration = context.package.directoryURL.appending(path: "swiftgen.yml")
    if fileManager.fileExists(atPath: configuration.path) {
      try swiftgen.run(configuration, environment: env(context: context))
    }

    // check each target
    let targetsFromArgs = parseTargets(arguments)
    let targets = context.package.targets
      .compactMap { $0 as? SourceModuleTarget }
      .filter { targetsFromArgs.isEmpty || targetsFromArgs.contains($0.name) }
    for target in targets {
      let configuration = target.directoryURL.appending(path: "swiftgen.yml")
      if fileManager.fileExists(atPath: configuration.path) {
        try swiftgen.run(configuration, environment: env(context: context, target: target))
      }
    }
  }
}

private extension SwiftGenPlugin {
  // Environment content for correct code generation
  func env(context: PluginContext, target: SourceModuleTarget? = nil) -> [String: String] {
    [
      "PROJECT_DIR": context.package.directoryURL.path,
      "TARGET_NAME": target?.name ?? "",
      "PRODUCT_MODULE_NAME": target?.moduleName ?? "",
      "DERIVED_SOURCES_DIR": context.pluginWorkDirectoryURL.path
    ]
  }

  func parseTargets(_ arguments: [String]) -> [String] {
    var result = [String]()
    for (i, arg) in arguments.enumerated() where arg == "--target" {
      let valueIdx = i + 1
      if valueIdx < arguments.count {
        result.append(arguments[valueIdx])
      }
    }
    return result
  }
}

private extension PluginContext.Tool {
  /// Invoke the tool with the given configuration
  func run(_ configuration: URL, environment: [String: String]) throws {
    try run(
      arguments: [
        "config",
        "run",
        "--config",
        configuration.path
      ],
      environment: environment
    )
  }

  /// Invoke the tool with given list of arguments
  func run(arguments: [String], environment: [String: String]) throws {
    let task = Process()
    task.executableURL = url
    task.arguments = arguments
    task.environment = environment

    try task.run()
    task.waitUntilExit()

    // Check whether the subprocess invocation was successful.
    if task.terminationReason == .exit && task.terminationStatus == 0 {
      // do something?
    } else {
      let problem = "\(task.terminationReason):\(task.terminationStatus)"
      Diagnostics.error("\(name) invocation failed: \(problem)")
    }
  }
}
