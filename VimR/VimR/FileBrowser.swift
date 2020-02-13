/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import RxSwift
import PureLayout
import CocoaFontAwesome

class FileBrowser: NSView,
                   UiComponent {

  typealias StateType = MainWindow.State

  enum Action {

    case open(url: URL, mode: MainWindow.OpenMode)
    case setAsWorkingDirectory(URL)
    case setShowHidden(Bool)
    case refresh
  }

  let innerCustomToolbar = InnerCustomToolbar()
  let menuItems: [NSMenuItem]

  override var isFirstResponder: Bool { self.fileView.isFirstResponder }

  required init(source: Observable<StateType>, emitter: ActionEmitter, state: StateType) {
    self.emit = emitter.typedEmit()
    self.uuid = state.uuid

    self.cwd = state.cwd

    self.fileView = FileOutlineView(source: source, emitter: emitter, state: state)

    self.showHiddenMenuItem = NSMenuItem(
      title: "Show Hidden Files",
      action: #selector(FileBrowser.showHiddenAction),
      keyEquivalent: ""
    )
    showHiddenMenuItem.boolState = state.fileBrowserShowHidden
    self.menuItems = [showHiddenMenuItem]

    super.init(frame: .zero)

    self.addViews()
    self.showHiddenMenuItem.target = self
    self.innerCustomToolbar.fileBrowser = self

    source
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { state in
        if self.cwd != state.cwd {
          self.cwd = state.cwd
          self.innerCustomToolbar.goToParentButton.isEnabled = state.cwd.path != "/"
        }

        self.currentBufferUrl = state.currentBuffer?.url
        self.showHiddenMenuItem.boolState = state.fileBrowserShowHidden
      })
      .disposed(by: self.disposeBag)
  }

  deinit { self.fileView.unbindTreeController() }

  private let emit: (UuidAction<Action>) -> Void
  private let disposeBag = DisposeBag()

  private let uuid: UUID

  private var currentBufferUrl: URL?

  private let fileView: FileOutlineView
  private let showHiddenMenuItem: NSMenuItem

  private var cwd: URL

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func addViews() {
    let scrollView = NSScrollView.standardScrollView()
    scrollView.borderType = .noBorder
    scrollView.documentView = self.fileView

    self.addSubview(scrollView)
    scrollView.autoPinEdgesToSuperviewEdges()
  }
}

extension FileBrowser {

  class InnerCustomToolbar: CustomToolBar {

    let goToParentButton = NSButton(forAutoLayout: ())
    let scrollToSourceButton = NSButton(forAutoLayout: ())
    let refreshButton = NSButton(forAutoLayout: ())

    init() {
      super.init(frame: .zero)
      self.configureForAutoLayout()

      self.addViews()
    }

    override func repaint(with theme: Workspace.Theme) {
      self.goToParentButton.image = NSImage.fontAwesomeIcon(
        name: .levelUpAlt,
        style: .solid,
        textColor: theme.toolbarForeground,
        dimension: InnerToolBar.iconDimension
      )

      self.scrollToSourceButton.image = NSImage.fontAwesomeIcon(
        name: .bullseye,
        style: .solid,
        textColor: theme.toolbarForeground,
        dimension: InnerToolBar.iconDimension
      )

      self.refreshButton.image = NSImage.fontAwesomeIcon(
        name: .sync,
        style: .solid,
        textColor: theme.toolbarForeground,
        dimension: InnerToolBar.iconDimension
      )
    }

    fileprivate weak var fileBrowser: FileBrowser? {
      didSet {
        self.goToParentButton.target = self.fileBrowser
        self.scrollToSourceButton.target = self.fileBrowser
        self.refreshButton.target = self.fileBrowser
      }
    }

    private func addViews() {
      let goToParent = self.goToParentButton
      InnerToolBar.configureToStandardIconButton(
        button: goToParent,
        iconName: .levelUpAlt,
        style: .solid
      )
      goToParent.toolTip = "Set parent as working directory"
      goToParent.action = #selector(FileBrowser.goToParentAction)

      let scrollToSource = self.scrollToSourceButton
      InnerToolBar.configureToStandardIconButton(
        button: scrollToSource,
        iconName: .bullseye,
        style: .solid
      )
      scrollToSource.toolTip = "Navigate to the current buffer"
      scrollToSource.action = #selector(FileBrowser.scrollToSourceAction)

      let refresh = self.refreshButton
      InnerToolBar.configureToStandardIconButton(button: refresh, iconName: .sync, style: .solid)
      refresh.toolTip = "Refresh"
      refresh.action = #selector(FileBrowser.refreshAction)

      self.addSubview(goToParent)
      self.addSubview(scrollToSource)
      self.addSubview(refresh)

      refresh.autoPinEdge(toSuperviewEdge: .top)
      refresh.autoPinEdge(toSuperviewEdge: .right, withInset: InnerToolBar.itemPadding)
      goToParent.autoPinEdge(toSuperviewEdge: .top)
      goToParent.autoPinEdge(.right, to: .left, of: refresh, withOffset: -InnerToolBar.itemPadding)
      scrollToSource.autoPinEdge(toSuperviewEdge: .top)
      scrollToSource.autoPinEdge(
        .right,
        to: .left,
        of: goToParent,
        withOffset: -InnerToolBar.itemPadding
      )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  }
}

// MARK: - Actions
extension FileBrowser {

  @objc func showHiddenAction(_ sender: Any?) {
    guard let menuItem = sender as? NSMenuItem else { return }

    self.emit(UuidAction(uuid: self.uuid, action: .setShowHidden(!menuItem.boolState)))
  }

  @objc func goToParentAction(_ sender: Any?) {
    self.emit(UuidAction(uuid: self.uuid, action: .setAsWorkingDirectory(self.cwd.parent)))
  }

  @objc func scrollToSourceAction(_ sender: Any?) {
    guard let url = self.currentBufferUrl else { return }

    self.fileView.select(url)
  }

  @objc func refreshAction(_ sender: Any?) {
    self.emit(UuidAction(uuid: self.uuid, action: .refresh))
  }
}
