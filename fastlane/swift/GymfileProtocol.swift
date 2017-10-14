protocol GymfileProtocol: class {
  var workspace: String? { get }
  var project: String? { get }
  var scheme: String? { get }
  var clean: Bool { get }
  var outputDirectory: String { get }
  var outputName: String? { get }
  var configuration: String? { get }
  var silent: Bool { get }
  var codesigningIdentity: String? { get }
  var skipPackageIpa: Bool { get }
  var includeSymbols: String? { get }
  var includeBitcode: String? { get }
  var exportMethod: String? { get }
  var exportOptions: String? { get }
  var exportXcargs: String? { get }
  var skipBuildArchive: String? { get }
  var skipArchive: String? { get }
  var buildPath: String? { get }
  var archivePath: String? { get }
  var derivedDataPath: String? { get }
  var resultBundle: String? { get }
  var buildlogPath: String { get }
  var sdk: String? { get }
  var toolchain: String? { get }
  var destination: String? { get }
  var exportTeamId: String? { get }
  var xcargs: String? { get }
  var xcconfig: String? { get }
  var suppressXcodeOutput: String? { get }
  var disableXcpretty: String? { get }
  var xcprettyTestFormat: String? { get }
  var xcprettyFormatter: String? { get }
  var xcprettyReportJunit: String? { get }
  var xcprettyReportHtml: String? { get }
  var xcprettyReportJson: String? { get }
  var analyzeBuildTime: String? { get }
  var xcprettyUtf: String? { get }
}

extension GymfileProtocol {
  var workspace: String? { return nil }
  var project: String? { return nil }
  var scheme: String? { return nil }
  var clean: Bool { return false }
  var outputDirectory: String { return "." }
  var outputName: String? { return nil }
  var configuration: String? { return nil }
  var silent: Bool { return false }
  var codesigningIdentity: String? { return nil }
  var skipPackageIpa: Bool { return false }
  var includeSymbols: String? { return nil }
  var includeBitcode: String? { return nil }
  var exportMethod: String? { return nil }
  var exportOptions: String? { return nil }
  var exportXcargs: String? { return nil }
  var skipBuildArchive: String? { return nil }
  var skipArchive: String? { return nil }
  var buildPath: String? { return nil }
  var archivePath: String? { return nil }
  var derivedDataPath: String? { return nil }
  var resultBundle: String? { return nil }
  var buildlogPath: String { return "~/Library/Logs/gym" }
  var sdk: String? { return nil }
  var toolchain: String? { return nil }
  var destination: String? { return nil }
  var exportTeamId: String? { return nil }
  var xcargs: String? { return nil }
  var xcconfig: String? { return nil }
  var suppressXcodeOutput: String? { return nil }
  var disableXcpretty: String? { return nil }
  var xcprettyTestFormat: String? { return nil }
  var xcprettyFormatter: String? { return nil }
  var xcprettyReportJunit: String? { return nil }
  var xcprettyReportHtml: String? { return nil }
  var xcprettyReportJson: String? { return nil }
  var analyzeBuildTime: String? { return nil }
  var xcprettyUtf: String? { return nil }
}
