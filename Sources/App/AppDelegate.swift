import AppKit
import SwiftUI

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow?
    var appState: AppState!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize app state
        appState = AppState()
        
        // Setup main menu
        setupMainMenu()
        
        // Open main window immediately
        openMainWindow()
        
        // Load initial data
        Task {
            await appState.loadInitialData()
        }
        
        print("🚀 AgenticHub started")
    }
    
    // MARK: - Menu Setup
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App menu (AgenticHub)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        // About
        let aboutItem = NSMenuItem(title: "À propos d'AgenticHub", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Réglages...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        
        appMenu.addItem(.separator())
        
        // Hide
        let hideItem = NSMenuItem(title: "Masquer AgenticHub", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hideItem)
        
        // Hide Others
        let hideOthersItem = NSMenuItem(title: "Masquer les autres", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        // Show All
        let showAllItem = NSMenuItem(title: "Tout afficher", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(showAllItem)
        
        appMenu.addItem(.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quitter AgenticHub", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        
        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        
        let fileMenu = NSMenu(title: "Fichier")
        fileMenuItem.submenu = fileMenu
        
        let refreshItem = NSMenuItem(title: "Actualiser", action: #selector(refreshData), keyEquivalent: "r")
        refreshItem.target = self
        fileMenu.addItem(refreshItem)
        
        fileMenu.addItem(.separator())
        
        let closeItem = NSMenuItem(title: "Fermer la fenêtre", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(closeItem)
        
        // Edit menu (standard)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        
        let editMenu = NSMenu(title: "Édition")
        editMenuItem.submenu = editMenu
        
        editMenu.addItem(NSMenuItem(title: "Annuler", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Rétablir", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Tout sélectionner", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        
        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        
        let windowMenu = NSMenu(title: "Fenêtre")
        windowMenuItem.submenu = windowMenu
        
        let minimizeItem = NSMenuItem(title: "Placer dans le Dock", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(minimizeItem)
        
        let zoomItem = NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenu.addItem(zoomItem)
        
        windowMenu.addItem(.separator())
        
        let frontItem = NSMenuItem(title: "Tout ramener au premier plan", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenu.addItem(frontItem)
        
        // Help menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        
        let helpMenu = NSMenu(title: "Aide")
        helpMenuItem.submenu = helpMenu
        
        let documentationItem = NSMenuItem(title: "Documentation MCP", action: #selector(openMCPDocs), keyEquivalent: "")
        documentationItem.target = self
        helpMenu.addItem(documentationItem)
        
        let skillsDocsItem = NSMenuItem(title: "Documentation Skills.sh", action: #selector(openSkillsDocs), keyEquivalent: "")
        skillsDocsItem.target = self
        helpMenu.addItem(skillsDocsItem)
        
        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
        NSApp.helpMenu = helpMenu
    }
    
    // MARK: - Menu Actions
    
    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc func showSettings() {
        // TODO: Implement settings window
        print("Settings not implemented yet")
    }
    
    @objc func refreshData() {
        Task {
            await appState.refreshAll()
        }
    }
    
    @objc func openMCPDocs() {
        if let url = URL(string: "https://modelcontextprotocol.io") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func openSkillsDocs() {
        if let url = URL(string: "https://skills.sh") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Window Management
    
    func openMainWindow() {
        if mainWindow == nil {
            let contentView = MainWindowView()
                .environmentObject(appState)
            
            mainWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            mainWindow?.title = "AgenticHub"
            mainWindow?.contentView = NSHostingView(rootView: contentView)
            mainWindow?.center()
            mainWindow?.setFrameAutosaveName("MainWindow")
            mainWindow?.minSize = NSSize(width: 900, height: 600)
        }
        
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

