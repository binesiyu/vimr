/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import RxSwift
import PureLayout
import Sparkle
import CocoaFontAwesome
import os

let debugMenuItemIdentifier = NSUserInterfaceItemIdentifier("debug-menu-item")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {

  struct OpenConfig {

    var urls: [URL]
    var cwd: URL

    var cliPipePath: String?
    var nvimArgs: [String]?
    var envDict: [String: String]?
    var line: Int?
  }

  enum Action {

    case newMainWindow(config: OpenConfig)
    case openInKeyWindow(config: OpenConfig)

    case preferences
  }

  override init() {
    let baseServerUrl = URL(string: "http://localhost:\(NetUtils.openPort())")!

    var initialAppState: AppState

    let dictDecoder = DictionaryDecoder()
    if let stateDict = UserDefaults.standard.value(forKey: PrefMiddleware.compatibleVersion) as? [String: Any],
       let state = try? dictDecoder.decode(AppState.self, from: stateDict) {

      initialAppState = state
    } else {
      initialAppState = .default
    }

    initialAppState.mainWindowTemplate.htmlPreview.server = nil

    self.context = Context(baseServerUrl: baseServerUrl, state: initialAppState)
    self.emit = self.context.actionEmitter.typedEmit()

    self.openNewMainWindowOnLaunch = initialAppState.openNewMainWindowOnLaunch
    self.openNewMainWindowOnReactivation = initialAppState.openNewMainWindowOnReactivation
    self.useSnapshot = initialAppState.useSnapshotUpdate

    super.init()
  }

  override func awakeFromNib() {
    super.awakeFromNib()

    let source = self.context.stateSource

    // We want to build the menu items tree at some point, eg in the init() of
    // ShortcutsPref. We have to do that *after* the MainMenu.xib is loaded.
    // Therefore, we use optional var for the self.uiRoot. Ugly, but, well...
    self.uiRoot = UiRoot(
      source: source,
      emitter: self.context.actionEmitter,
      state: self.context.state
    )

    source
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { appState in
        self.hasMainWindows = !appState.mainWindows.isEmpty
        self.hasDirtyWindows = appState.mainWindows.values.reduce(false) { $1.isDirty ? true : $0 }

        self.openNewMainWindowOnLaunch = appState.openNewMainWindowOnLaunch
        self.openNewMainWindowOnReactivation = appState.openNewMainWindowOnReactivation

        if self.useSnapshot != appState.useSnapshotUpdate {
          self.useSnapshot = appState.useSnapshotUpdate
          self.setSparkleUrl(self.useSnapshot)
        }

        if appState.quit { NSApp.terminate(self) }
      })
      .disposed(by: self.disposeBag)
  }

  private let context: Context
  private let emit: (Action) -> Void

  private var uiRoot: UiRoot?

  private var hasDirtyWindows = false
  private var hasMainWindows = false

  private var openNewMainWindowOnLaunch: Bool
  private var openNewMainWindowOnReactivation: Bool
  private var useSnapshot: Bool

  private let disposeBag = DisposeBag()

  private var launching = true

  private let log = OSLog(subsystem: Defs.loggerSubsystem,
                          category: Defs.LoggerCategory.general)

  private func setSparkleUrl(_ snapshot: Bool) {
    if snapshot {
      updater.feedURL = URL(
        string: "https://raw.githubusercontent.com/qvacua/vimr/develop/appcast_snapshot.xml"
      )
    } else {
      updater.feedURL = URL(
        string: "https://raw.githubusercontent.com/qvacua/vimr/master/appcast.xml"
      )
    }
  }
}

// MARK: - NSApplicationDelegate
extension AppDelegate {

  func applicationWillFinishLaunching(_: Notification) {
    self.launching = true

    let appleEventManager = NSAppleEventManager.shared()
    appleEventManager.setEventHandler(self,
                                      andSelector: #selector(AppDelegate.handle(getUrlEvent:replyEvent:)),
                                      forEventClass: UInt32(kInternetEventClass),
                                      andEventID: UInt32(kAEGetURL))
  }

  func applicationDidFinishLaunching(_: Notification) {
    self.launching = false

    #if DEBUG
    NSApp.mainMenu?.items.first { $0.identifier == debugMenuItemIdentifier }?.isHidden = false
    #endif
  }

  func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
    if self.launching {
      if self.openNewMainWindowOnLaunch {
        self.newDocument(self)
        return true
      }
    } else {
      if self.openNewMainWindowOnReactivation {
        self.newDocument(self)
        return true
      }
    }

    return false
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    self.context.savePrefs()

    guard self.hasMainWindows else {
      self.uiRoot?.prepareQuit()
      return .terminateNow
    }

    // check first whether there are blocked nvim instances, if so, abort and inform the user
    if self.uiRoot?.hasBlockedWindows() == true {
      let alert = NSAlert()
      alert.messageText = "There are windows waiting for your input."
      alert.alertStyle = .informational
      alert.runModal()
      return .terminateCancel
    }

    if self.hasDirtyWindows {
      let alert = NSAlert()
      alert.addButton(withTitle: "Cancel")
      let discardAndQuitButton = alert.addButton(withTitle: "Discard and Quit")
      alert.messageText = "There are windows with unsaved buffers!"
      alert.alertStyle = .warning
      discardAndQuitButton.keyEquivalentModifierMask = .command
      discardAndQuitButton.keyEquivalent = "d"

      if alert.runModal() == .alertSecondButtonReturn {
        self.updateMainWindowTemplateBeforeQuitting()
        self.uiRoot?.prepareQuit()
        return .terminateNow
      }

      return .terminateCancel
    }

    self.updateMainWindowTemplateBeforeQuitting()
    self.uiRoot?.prepareQuit()
    return .terminateNow
  }

  // For drag & dropping files on the App icon.
  func application(_ sender: NSApplication, openFiles filenames: [String]) {
    let urls = filenames.map { URL(fileURLWithPath: $0) }
    let config = OpenConfig(
      urls: urls, cwd: FileUtils.userHomeUrl, cliPipePath: nil, nvimArgs: nil, envDict: nil, line: nil
    )
    self.emit(.newMainWindow(config: config))

    sender.reply(toOpenOrPrint: .success)
  }

  private func updateMainWindowTemplateBeforeQuitting() {
    guard let curMainWindow = self.context.state.currentMainWindow else { return }

    self.context.state.mainWindowTemplate = curMainWindow
    self.context.savePrefs()
  }
}

// MARK: - AppleScript
extension AppDelegate {

  @objc func handle(getUrlEvent event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
    guard let urlString = event.paramDescriptor(forKeyword: UInt32(keyDirectObject))?.stringValue else {
      return
    }

    guard let url = URL(string: urlString) else {
      return
    }

    guard url.scheme == "vimr" else {
      return
    }

    guard let rawAction = url.host else {
      return
    }

    guard let action = VimRUrlAction(rawValue: rawAction) else {
      return
    }

    let rawParams = url.query?.components(separatedBy: "&") ?? []

    guard let pipePath = queryParam(pipePathPrefix, from: rawParams, transforming: identity).first else {
      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = "Outdated Command Line Tool?"
      alert.informativeText = "It seems that the installed vimr command line tool is outdated." +
                              "Please re-install it from the General Preferences."
      alert.runModal()

      return
    }

    guard FileManager.default.fileExists(atPath: pipePath) else {
      // Use pipePath as a kind of nonce
      return
    }

    let dict = try? FileManager.default.attributesOfItem(atPath: pipePath) as NSDictionary
    guard dict?.filePosixPermissions() == 0o600 else {
      // Use pipePath as a kind of nonce
      return
    }

    let envDict: [String: String]?
    if let envPath = queryParam(envPathPrefix, from: rawParams, transforming: identity).first {
      envDict = stringDict(from: URL(fileURLWithPath: envPath))
      if FileManager.default.fileExists(atPath: envPath) {
        do {
          try FileManager.default.removeItem(atPath: envPath)
        } catch {
          self.log.error(error.localizedDescription)
        }
      }
    } else {
      envDict = nil
    }

    let line = queryParam(linePrefix, from: rawParams, transforming: { Int($0) }).compactMap { $0 }.first
    let urls = queryParam(filePrefix, from: rawParams, transforming: { URL(fileURLWithPath: $0) })
    let cwd = queryParam(cwdPrefix,
                         from: rawParams,
                         transforming: { URL(fileURLWithPath: $0) }).first ?? FileUtils.userHomeUrl
    let wait = queryParam(waitPrefix, from: rawParams, transforming: { $0 == "true" ? true : false }).first ?? false

    if wait == false {
      _ = Darwin.close(Darwin.open(pipePath, O_WRONLY))
    }

    // If we don't do this, the window is active, but not in front.
    NSApp.activate(ignoringOtherApps: true)

    switch action {

    case .activate, .newWindow:
      let config = OpenConfig(urls: urls, cwd: cwd, cliPipePath: pipePath, nvimArgs: nil, envDict: envDict, line: line)
      self.emit(.newMainWindow(config: config))

    case .open:
      let config = OpenConfig(urls: urls, cwd: cwd, cliPipePath: pipePath, nvimArgs: nil, envDict: envDict, line: line)
      self.emit(.openInKeyWindow(config: config))

    case .separateWindows:
      urls.forEach {
        let config = OpenConfig(urls: [$0], cwd: cwd, cliPipePath: pipePath, nvimArgs: nil, envDict: nil, line: line)
        self.emit(.newMainWindow(config: config))
      }

    case .nvim:
      let config = OpenConfig(urls: urls,
                              cwd: cwd,
                              cliPipePath: pipePath,
                              nvimArgs: queryParam(nvimArgsPrefix, from: rawParams, transforming: identity),
                              envDict: envDict,
                              line: line)
      self.emit(.newMainWindow(config: config))

    }
  }

  private func stringDict(from jsonUrl: URL) -> [String: String]? {
    guard let data = try? Data(contentsOf: jsonUrl) else {
      return nil
    }

    do {
      return try JSONSerialization.jsonObject(with: data) as? [String: String]
    } catch {
      self.log.error(error.localizedDescription)
    }

    return nil
  }

  private func queryParam<T>(_ prefix: String,
                             from rawParams: [String],
                             transforming transform: (String) -> T) -> [T] {

    return rawParams
      .filter { $0.hasPrefix(prefix) }
      .compactMap { $0.without(prefix: prefix).removingPercentEncoding }
      .map(transform)
  }
}

// MARK: - IBActions
extension AppDelegate {

  @IBAction func checkForUpdates(_ sender: Any?) {
    updater.checkForUpdates(sender)
  }

  @IBAction func newDocument(_ sender: Any?) {
    let config = OpenConfig(
      urls: [], cwd: FileUtils.userHomeUrl, cliPipePath: nil, nvimArgs: nil, envDict: nil, line: nil
    )
    self.emit(.newMainWindow(config: config))
  }

  @IBAction func openInNewWindow(_ sender: Any?) {
    self.openDocument(sender)
  }

  @IBAction func showPrefWindow(_ sender: Any?) {
    self.emit(.preferences)
  }

  // Invoked when no main window is open.
  @IBAction func openDocument(_: Any?) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.begin { result in
      guard result == .OK else {
        return
      }

      let urls = panel.urls
      let commonParentUrl = FileUtils.commonParent(of: urls)

      let config = OpenConfig(
        urls: urls, cwd: commonParentUrl, cliPipePath: nil, nvimArgs: nil, envDict: nil, line: nil
      )
      self.emit(.newMainWindow(config: config))
    }
  }
}

// MARK: - NSUserNotificationCenterDelegate
extension AppDelegate {

  public func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent _: NSUserNotification) -> Bool {
    return true
  }
}

// Keep the rawValues in sync with Action in the `vimr` Python script.
private enum VimRUrlAction: String {
  case activate = "activate"
  case open = "open"
  case newWindow = "open-in-new-window"
  case separateWindows = "open-in-separate-windows"
  case nvim = "nvim"
}

private let updater = SUUpdater()

// Keep in sync with QueryParamKey in the `vimr` Python script.
private let filePrefix = "file="
private let cwdPrefix = "cwd="
private let nvimArgsPrefix = "nvim-args="
private let pipePathPrefix = "pipe-path="
private let waitPrefix = "wait="
private let envPathPrefix = "env-path="
private let linePrefix = "line="
