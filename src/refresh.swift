import Common

/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input.
/// The function is idempotent.
func refreshSession<T>(startup: Bool = false, forceFocus: Bool = false, body: () -> T) -> T {
    check(Thread.current.isMainThread)
    gc()

    detectNewWindowsAndAttachThemToWorkspaces(startup: startup)

    let nativeFocused = getNativeFocusedWindow(startup: startup)
    if let nativeFocused { debugWindowsIfRecording(nativeFocused) }
    takeFocusFromMacOs(nativeFocused, startup: startup)
    let focusBefore = focusedWindow

    refreshModel()
    let result = body()
    refreshModel()

    let focusAfter = focusedWindow

    if startup {
        arrangeLayoutsAtStartup()
    }

    if TrayMenuModel.shared.isEnabled {
        if forceFocus || focusBefore != focusAfter {
            focusedWindow?.nativeFocus() // syncFocusToMacOs
        }

        updateTrayText()
        layoutWorkspaces()
    }
    
    let notificationName = NSNotification.Name("bobko.aerospace.Layout")
    // Create an empty dictionary to store workspace information
    var workspacesInfo: [String: Any] = [:]

    // Iterate through all workspaces
    for workspace in Workspace.all {
        // Create an empty array to store window information for the current workspace
        var windowsInfo: [[String: Any]] = []

        // Iterate through all windows in the current workspace
        for window in workspace.allLeafWindowsRecursive {
    
            if (window.app.id == nil) {
                continue;
            }
            
            // Create a dictionary for each window
            let windowInfo: [String: Any] = [
                "id": window.app.id as Any
                // Add more window information if needed
            ]

            // Append the window information to the array
            windowsInfo.append(windowInfo)
        }

        // Create a dictionary for the current workspace
        let workspaceInfo: [String: Any] = [
            "windows": windowsInfo,
            "screen": workspace.monitor.name,
            // Add more workspace information if needed
        ]

        // Add the workspace information to the main dictionary using the workspace name as the key
        workspacesInfo[workspace.name] = workspaceInfo
    }
    
    // Check if the overall information has changed since the last notification
    let lastUserInfo = UserDefaults.standard.dictionary(forKey: "lastUserInfo")
    if (lastUserInfo == nil) || workspacesInfo as NSDictionary != lastUserInfo! as NSDictionary {
        // Construct the final userInfo dictionary
        let userInfo: [AnyHashable: Any] = ["workspaces": workspacesInfo]

        // Post the notification with the userInfo dictionary
        DistributedNotificationCenter.default().postNotificationName(notificationName, object: nil, userInfo: userInfo, deliverImmediately: true)

        // Update the lastUserInfo in UserDefaults
        UserDefaults.standard.set(workspacesInfo, forKey: "lastUserInfo")
    }

    return result
}

func refreshAndLayout(startup: Bool = false) {
    refreshSession(startup: startup, body: {})
}

func refreshModel() {
    gc()
    refreshFocusedWorkspaceBasedOnFocusedWindow()
    normalizeContainers()
}

private func gc() {
    // Garbage collect terminated apps and windows before working with all windows
    MacApp.garbageCollectTerminatedApps()
    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    refreshAndLayout()
}

func takeFocusFromMacOs(_ nativeFocused: Window?, startup: Bool) { // alternative name: syncFocusFromMacOs
    if let nativeFocused, getFocusSourceOfTruth(startup: startup) == .macOs {
        nativeFocused.focus()
        setFocusSourceOfTruth(.ownModel, startup: startup)
    }
}

private func refreshFocusedWorkspaceBasedOnFocusedWindow() { // todo drop. It should no longer be necessary
    if let focusedWindow = focusedWindow {
        let focusedWorkspace: Workspace = focusedWindow.workspace
        check(focusedWorkspace.monitor.setActiveWorkspace(focusedWorkspace))
        focusedWorkspaceName = focusedWorkspace.name
    }
}

private func layoutWorkspaces() {
    for workspace in Workspace.all {
        if workspace.isVisible {
            // todo no need to unhide tiling windows (except for keeping hide/unhide state variables invariants)
            workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideViaEmulation() } // todo as!
        } else {
            workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).hideViaEmulation() } // todo as!
        }
    }
    for monitor in monitors {
        monitor.activeWorkspace.layoutWorkspace()
    }
}

private func normalizeContainers() {
    for workspace in Workspace.all { // todo do it only for visible workspaces?
        workspace.normalizeContainers()
    }
}

private func detectNewWindowsAndAttachThemToWorkspaces(startup: Bool) {
    for app in apps {
        let _ = app.detectNewWindowsAndGetAll(startup: startup)
    }
}

private func arrangeLayoutsAtStartup() {
    for workspace in Workspace.all.filter({ !$0.isEffectivelyEmpty }) {
        let root = workspace.rootTilingContainer
        if root.children.count <= 3 {
            root.layout = .tiles
        } else {
            root.layout = .accordion
        }
    }
}
