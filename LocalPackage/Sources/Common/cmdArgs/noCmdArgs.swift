public struct CloseCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.close, allowInConfig: true)
}
public struct CloseAllWindowsButCurrentCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.closeAllWindowsButCurrent, allowInConfig: true)
}
public struct FlattenWorkspaceTreeCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.flattenWorkspaceTree, allowInConfig: true)
}
public struct FullscreenCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.fullscreen, allowInConfig: true)
}
public struct ReloadConfigCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.reloadConfig, allowInConfig: true)
}
public struct WorkspaceBackAndForthCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.workspaceBackAndForth, allowInConfig: true)
}
public struct ListAppsCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.listApps, allowInConfig: false)
}
public struct ServerVersionInternalCommandCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.serverVersionInternalCommand, allowInConfig: false)
}

func noArgsParser<T : Copyable>(_ kind: CmdKind, allowInConfig: Bool) -> CmdParser<T> {
    cmdParser(
        kind: kind,
        allowInConfig: allowInConfig,
        help: """
              USAGE: \(kind) [-h|--help]

              OPTIONS:
                -h, --help   Print help
              """,
        options: [:],
        arguments: []
    )
}
