/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import PureLayout
import RxSwift

class GeneralPref: PrefPane, UiComponent, NSTextFieldDelegate {

  typealias StateType = AppState

  enum Action {

    case setOpenOnLaunch(Bool)
    case setAfterLastWindowAction(AppState.AfterLastWindowAction)
    case setOpenOnReactivation(Bool)
    case setDefaultUsesVcsIgnores(Bool)
  }

  override var displayName: String {
    return "General"
  }

  override var pinToContainer: Bool {
    return true
  }

  required init(source: Observable<StateType>, emitter: ActionEmitter, state: StateType) {
    self.emit = emitter.typedEmit()

    super.init(frame: .zero)

    self.addViews()

    self.openWhenLaunchingCheckbox.boolState = state.openNewMainWindowOnLaunch
    self.openOnReactivationCheckbox.boolState = state.openNewMainWindowOnReactivation
    self.defaultUsesVcsIgnoresCheckbox.boolState = state.openQuickly.defaultUsesVcsIgnores

    self.lastWindowAction = state.afterLastWindowAction
    self.afterLastWindowPopup.selectItem(at: indexToAfterLastWindowAction.firstIndex(of: state.afterLastWindowAction) ?? 0)

    source
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { state in
        if self.openWhenLaunchingCheckbox.boolState != state.openNewMainWindowOnLaunch {
          self.openWhenLaunchingCheckbox.boolState = state.openNewMainWindowOnLaunch
        }

        if self.openOnReactivationCheckbox.boolState != state.openNewMainWindowOnReactivation {
          self.openOnReactivationCheckbox.boolState = state.openNewMainWindowOnReactivation
        }

        if self.lastWindowAction != state.afterLastWindowAction {
          self.afterLastWindowPopup.selectItem(
            at: indexToAfterLastWindowAction.firstIndex(of: state.afterLastWindowAction) ?? 0
          )
        }
        self.lastWindowAction = state.afterLastWindowAction
      })
      .disposed(by: self.disposeBag)
  }

  private let emit: (Action) -> Void
  private let disposeBag = DisposeBag()

  private var lastWindowAction = AppState.AfterLastWindowAction.doNothing

  private let openWhenLaunchingCheckbox = NSButton(forAutoLayout: ())
  private let openOnReactivationCheckbox = NSButton(forAutoLayout: ())
  private let defaultUsesVcsIgnoresCheckbox = NSButton(forAutoLayout: ())

  private let afterLastWindowPopup = NSPopUpButton(forAutoLayout: ())

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func addViews() {
    let paneTitle = self.paneTitleTextField(title: "General")

    let openUntitledWindowTitle = self.titleTextField(title: "Open Untitled Window:")
    self.configureCheckbox(button: self.openWhenLaunchingCheckbox,
                           title: "On launch",
                           action: #selector(GeneralPref.openUntitledWindowWhenLaunchingAction))
    self.configureCheckbox(button: self.openOnReactivationCheckbox,
                           title: "On re-activation",
                           action: #selector(GeneralPref.openUntitledWindowOnReactivationAction))
    self.configureCheckbox(button: self.defaultUsesVcsIgnoresCheckbox,
                           title: "Use VCS Ignores",
                           action: #selector(GeneralPref.defaultUsesVcsIgnoresAction))

    let whenLaunching = self.openWhenLaunchingCheckbox
    let onReactivation = self.openOnReactivationCheckbox

    let afterLastWindowTitle = self.titleTextField(title: "After Last Window Closes:")
    let lastWindow = self.afterLastWindowPopup
    lastWindow.target = self
    lastWindow.action = #selector(GeneralPref.afterLastWindowAction)
    lastWindow.addItems(withTitles: [
      "Do Nothing",
      "Hide",
      "Quit",
    ])

    let ignoreListTitle = self.titleTextField(title: "Open Quickly:")
    let ignoreInfo =
      self.infoTextField(
        markdown:
        """
        When checked, the ignore files of VCSs, e.g. `gitignore`, will we used to ignore files.  
        This checkbox will set the initial value for each VimR window.  
        You can change this setting for each VimR window in the Open Quickly window.  
        The behavior should be almost identical to that of
        [The Silver Searcher](https://github.com/ggreer/the_silver_searcher).
        """
      )

    let cliToolTitle = self.titleTextField(title: "CLI Tool:")
    let cliToolButton = NSButton(forAutoLayout: ())
    cliToolButton.title = "Copy 'vimr' CLI Tool..."
    cliToolButton.bezelStyle = .rounded
    cliToolButton.isBordered = true
    cliToolButton.setButtonType(.momentaryPushIn)
    cliToolButton.target = self
    cliToolButton.action = #selector(GeneralPref.copyCliTool(_:))
    let cliToolInfo = self.infoTextField(
      markdown: "Put the executable `vimr` in your `$PATH` and execute `vimr -h` for help."
    )

    let vcsIg = self.defaultUsesVcsIgnoresCheckbox

    self.addSubview(paneTitle)
    self.addSubview(openUntitledWindowTitle)
    self.addSubview(whenLaunching)
    self.addSubview(onReactivation)

    self.addSubview(vcsIg)
    self.addSubview(ignoreListTitle)
    self.addSubview(ignoreInfo)

    self.addSubview(afterLastWindowTitle)
    self.addSubview(lastWindow)

    self.addSubview(cliToolTitle)
    self.addSubview(cliToolButton)
    self.addSubview(cliToolInfo)

    paneTitle.autoPinEdge(toSuperviewEdge: .top, withInset: 18)
    paneTitle.autoPinEdge(toSuperviewEdge: .left, withInset: 18)
    paneTitle.autoPinEdge(toSuperviewEdge: .right, withInset: 18, relation: .greaterThanOrEqual)

    openUntitledWindowTitle.autoAlignAxis(.baseline, toSameAxisOf: whenLaunching, withOffset: 0)
    openUntitledWindowTitle.autoPinEdge(.right, to: .right, of: afterLastWindowTitle)
    openUntitledWindowTitle.autoPinEdge(toSuperviewEdge: .left, withInset: 18, relation: .greaterThanOrEqual)

    whenLaunching.autoPinEdge(.top, to: .bottom, of: paneTitle, withOffset: 18)
    whenLaunching.autoPinEdge(.left, to: .right, of: openUntitledWindowTitle, withOffset: 5)
    whenLaunching.autoPinEdge(toSuperviewEdge: .right, withInset: 18, relation: .greaterThanOrEqual)

    onReactivation.autoPinEdge(.top, to: .bottom, of: whenLaunching, withOffset: 5)
    onReactivation.autoPinEdge(.left, to: .left, of: whenLaunching)
    onReactivation.autoPinEdge(toSuperviewEdge: .right, withInset: 18, relation: .greaterThanOrEqual)

    afterLastWindowTitle.autoAlignAxis(.baseline, toSameAxisOf: lastWindow)
    afterLastWindowTitle.autoPinEdge(toSuperviewEdge: .left, withInset: 18)

    lastWindow.autoPinEdge(.top, to: .bottom, of: onReactivation, withOffset: 18)
    lastWindow.autoPinEdge(.left, to: .right, of: afterLastWindowTitle, withOffset: 5)

    ignoreListTitle.autoAlignAxis(.baseline, toSameAxisOf: vcsIg)
    ignoreListTitle.autoPinEdge(.right, to: .right, of: openUntitledWindowTitle)
    ignoreListTitle.autoPinEdge(toSuperviewEdge: .left, withInset: 18, relation: .greaterThanOrEqual)

    vcsIg.autoPinEdge(.top, to: .bottom, of: lastWindow, withOffset: 18)
    vcsIg.autoPinEdge(.left, to: .right, of: ignoreListTitle, withOffset: 5)

    ignoreInfo.autoPinEdge(.top, to: .bottom, of: vcsIg, withOffset: 5)
    ignoreInfo.autoPinEdge(toSuperviewEdge: .right, withInset: 18)
    ignoreInfo.autoPinEdge(.left, to: .left, of: vcsIg)

    cliToolTitle.autoAlignAxis(.baseline, toSameAxisOf: cliToolButton)
    cliToolTitle.autoPinEdge(toSuperviewEdge: .left, withInset: 18, relation: .greaterThanOrEqual)
    cliToolTitle.autoPinEdge(.right, to: .right, of: openUntitledWindowTitle)

    cliToolButton.autoPinEdge(.top, to: .bottom, of: ignoreInfo, withOffset: 18)
    cliToolButton.autoPinEdge(toSuperviewEdge: .right, withInset: 18, relation: .greaterThanOrEqual)
    cliToolButton.autoPinEdge(.left, to: .right, of: cliToolTitle, withOffset: 5)

    cliToolInfo.autoPinEdge(.top, to: .bottom, of: cliToolButton, withOffset: 5)
    cliToolInfo.autoPinEdge(toSuperviewEdge: .right, withInset: 18, relation: .greaterThanOrEqual)
    cliToolInfo.autoPinEdge(.left, to: .right, of: cliToolTitle, withOffset: 5)
  }
}

// MARK: - Actions
extension GeneralPref {

  @objc func copyCliTool(_ sender: NSButton) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true

    panel.beginSheetModal(for: self.window!) { result in
      guard result == .OK else {
        return
      }

      guard let vimrUrl = Bundle.main.url(forResource: "vimr", withExtension: nil) else {
        self.alert(title: "Something Went Wrong.",
                   info: "The CLI tool 'vimr' could not be found. Please re-download VimR and try again.")
        return
      }

      guard let targetUrl = panel.url?.appendingPathComponent("vimr") else {
        self.alert(title: "Something Went Wrong.",
                   info: "The target directory could not be determined. Please try again with a different directory.")
        return
      }

      do {
        try FileManager.default.copyItem(at: vimrUrl, to: targetUrl)
      } catch let err as NSError {
        self.alert(title: "Error copying 'vimr'", info: err.localizedDescription)
      }
    }
  }

  @objc func defaultUsesVcsIgnoresAction(_ sender: NSButton) {
    self.emit(.setDefaultUsesVcsIgnores(sender.boolState))
  }

  @objc func openUntitledWindowWhenLaunchingAction(_ sender: NSButton) {
    self.emit(.setOpenOnLaunch(self.openWhenLaunchingCheckbox.boolState))
  }

  @objc func openUntitledWindowOnReactivationAction(_ sender: NSButton) {
    self.emit(.setOpenOnReactivation(self.openOnReactivationCheckbox.boolState))
  }

  @objc func afterLastWindowAction(_ sender: NSPopUpButton) {
    let index = sender.indexOfSelectedItem

    guard index >= 0 && index <= 2 else {
      return
    }

    self.lastWindowAction = indexToAfterLastWindowAction[index]
    self.emit(.setAfterLastWindowAction(self.lastWindowAction))
  }

  private func alert(title: String, info: String) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = title
    alert.informativeText = info
    alert.runModal()
  }
}

private let indexToAfterLastWindowAction: [AppState.AfterLastWindowAction] = [.doNothing, .hide, .quit]
