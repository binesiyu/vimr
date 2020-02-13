/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import PureLayout
import RxSwift

class AppearancePref: PrefPane, NSComboBoxDelegate, NSControlTextEditingDelegate {

  typealias StateType = AppState

  enum Action {

    case setUsesColorscheme(Bool)
    case setShowsFileIcon(Bool)
    case setUsesLigatures(Bool)
    case setFont(NSFont)
    case setLinespacing(CGFloat)
    case setCharacterspacing(CGFloat)
  }

  override var displayName: String { "Appearance" }

  override var pinToContainer: Bool { true }

  override func windowWillClose() {
    self.linespacingAction()
    self.characterspacingAction()
  }

  override func paneWillAppear() {
    self.previewArea.textColor = NSColor.textColor
  }

  required init(source: Observable<StateType>, emitter: ActionEmitter, state: StateType) {
    self.emit = emitter.typedEmit()

    self.font = state.mainWindowTemplate.appearance.font
    self.linespacing = state.mainWindowTemplate.appearance.linespacing
    self.characterspacing = state.mainWindowTemplate.appearance.characterspacing
    self.usesLigatures = state.mainWindowTemplate.appearance.usesLigatures
    self.usesColorscheme = state.mainWindowTemplate.appearance.usesTheme
    self.showsFileIcon = state.mainWindowTemplate.appearance.showsFileIcon

    super.init(frame: .zero)

    self.addViews()
    self.updateViews()

    source
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { state in
        let appearance = state.mainWindowTemplate.appearance

        guard self.font != appearance.font
              || self.linespacing != appearance.linespacing
              || self.characterspacing != appearance.characterspacing
              || self.usesLigatures != appearance.usesLigatures
              || self.usesColorscheme != appearance.usesTheme
              || self.showsFileIcon != appearance.showsFileIcon
          else { return }

        self.font = appearance.font
        self.linespacing = appearance.linespacing
        self.characterspacing = appearance.characterspacing
        self.usesLigatures = appearance.usesLigatures
        self.usesColorscheme = appearance.usesTheme
        self.showsFileIcon = appearance.showsFileIcon

        self.updateViews()
      })
      .disposed(by: self.disposeBag)
  }

  private let emit: (Action) -> Void
  private let disposeBag = DisposeBag()

  private var font: NSFont
  private var linespacing: CGFloat
  private var characterspacing: CGFloat
  private var usesLigatures: Bool
  private var usesColorscheme: Bool
  private var showsFileIcon: Bool

  private let colorschemeCheckbox = NSButton(forAutoLayout: ())
  private let fileIconCheckbox = NSButton(forAutoLayout: ())

  private let sizes = [9, 10, 11, 12, 13, 14, 16, 18, 24, 36, 48, 64]
  private let sizeCombo = NSComboBox(forAutoLayout: ())
  private let fontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
  private let linespacingField = NSTextField(forAutoLayout: ())
  private let characterspacingField = NSTextField(forAutoLayout: ())
  private let ligatureCheckbox = NSButton(forAutoLayout: ())
  private let previewArea = NSTextView(frame: .zero)

  private let exampleText =
    """
    abcdefghijklmnopqrstuvwxyz
    ABCDEFGHIJKLMNOPQRSTUVWXYZ
    0123456789 -~ - ~
    (){}[] +-*/= .,;:!?#&$%@|^
    <- -> => >> << >>= =<< .. 
    :: -< >- -<< >>- ++ /= ==
    """

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func addViews() {
    let paneTitle = self.paneTitleTextField(title: "Appearance")

    let useColorscheme = self.colorschemeCheckbox
    self.configureCheckbox(
      button: useColorscheme,
      title: "Use Neovim's color scheme for main window and tools.",
      action: #selector(AppearancePref.usesColorschemeAction(_:))
    )

    let useColorschemeInfo = self.infoTextField(
      markdown: """
                If checked, the colors of the selected `colorscheme` will be
                used to render tools, e.g. the file browser.
                """
    )

    let fileIcon = self.fileIconCheckbox
    self.configureCheckbox(
      button: fileIcon,
      title: "Show file icons",
      action: #selector(AppearancePref.fileIconAction(_:))
    )

    let fileIconInfo = self.infoTextField(
      markdown: """
                In case the selected `colorscheme` does not play well with the file icons
                in the file browser and the buffer list, you can turn them off.
                """
    )

    let fontTitle = self.titleTextField(title: "Default Font:")

    let fontPopup = self.fontPopup
    fontPopup.target = self
    fontPopup.action = #selector(AppearancePref.fontPopupAction)

    // This takes quite some time.
    DispatchQueue.global(qos: .userInitiated).async {
      let fontNames = sharedFontManager.monospacedRegularFontNames()
      DispatchQueue.main.async {
        fontPopup.addItems(withTitles: fontNames)
        self.updateViews()
      }
    }

    let sizeCombo = self.sizeCombo
    sizeCombo.delegate = self
    sizeCombo.target = self
    sizeCombo.action = #selector(AppearancePref.sizeComboBoxDidEnter(_:))
    self.sizes.forEach { string in sizeCombo.addItem(withObjectValue: string) }

    let linespacingTitle = self.titleTextField(title: "Line Spacing:")
    let linespacingField = self.linespacingField

    let characterspacingTitle = self.titleTextField(title: "Character Spacing:")
    let characterspacingField = self.characterspacingField

    let characterspacingInfo = self.infoTextField(
      markdown: "Character spacing not equal to `1` will likely break ligatures."
    )

    let ligatureCheckbox = self.ligatureCheckbox
    self.configureCheckbox(
      button: ligatureCheckbox,
      title: "Use Ligatures",
      action: #selector(AppearancePref.usesLigaturesAction(_:))
    )

    let previewArea = self.previewArea
    previewArea.isEditable = true
    previewArea.maxSize = CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    previewArea.isVerticallyResizable = true
    previewArea.isHorizontallyResizable = true
    previewArea.textContainer?.heightTracksTextView = false
    previewArea.textContainer?.widthTracksTextView = false
    previewArea.autoresizingMask = [.width, .height]
    previewArea.textContainer?.containerSize = CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    previewArea.layoutManager?.replaceTextStorage(NSTextStorage(string: self.exampleText))
    previewArea.isRichText = false
    previewArea.turnOffLigatures(self)

    let previewScrollView = NSScrollView(forAutoLayout: ())
    previewScrollView.hasVerticalScroller = true
    previewScrollView.hasHorizontalScroller = true
    previewScrollView.autohidesScrollers = true
    previewScrollView.borderType = .bezelBorder
    previewScrollView.documentView = previewArea

    self.addSubview(paneTitle)

    self.addSubview(useColorscheme)
    self.addSubview(useColorschemeInfo)
    self.addSubview(fileIcon)
    self.addSubview(fileIconInfo)
    self.addSubview(fontTitle)
    self.addSubview(fontPopup)
    self.addSubview(sizeCombo)
    self.addSubview(linespacingTitle)
    self.addSubview(linespacingField)
    self.addSubview(characterspacingTitle)
    self.addSubview(characterspacingField)
    self.addSubview(characterspacingInfo)
    self.addSubview(ligatureCheckbox)
    self.addSubview(previewScrollView)

    paneTitle.autoPinEdge(toSuperviewEdge: .top, withInset: 18)
    paneTitle.autoPinEdge(toSuperviewEdge: .left, withInset: 18)

    useColorscheme.autoPinEdge(.left, to: .right, of: fontTitle, withOffset: 5)
    useColorscheme.autoPinEdge(.top, to: .bottom, of: paneTitle, withOffset: 18)

    useColorschemeInfo.autoPinEdge(.top, to: .bottom, of: useColorscheme, withOffset: 5)
    useColorschemeInfo.autoPinEdge(.left, to: .left, of: useColorscheme)

    fileIcon.autoPinEdge(.left, to: .right, of: fontTitle, withOffset: 5)
    fileIcon.autoPinEdge(.top, to: .bottom, of: useColorschemeInfo, withOffset: 18)

    fileIconInfo.autoPinEdge(.top, to: .bottom, of: fileIcon, withOffset: 5)
    fileIconInfo.autoPinEdge(.left, to: .left, of: fileIcon)

    fontTitle.autoPinEdge(toSuperviewEdge: .left, withInset: 18, relation: .greaterThanOrEqual)
    fontTitle.autoAlignAxis(.baseline, toSameAxisOf: fontPopup)

    fontPopup.autoPinEdge(.top, to: .bottom, of: fileIconInfo, withOffset: 18)
    fontPopup.autoPinEdge(.left, to: .right, of: fontTitle, withOffset: 5)
    fontPopup.autoSetDimension(.width, toSize: 240)

    sizeCombo.autoSetDimension(.width, toSize: 60)
    // If we use .Baseline the combo box is placed one pixel off...
    sizeCombo.autoAlignAxis(.horizontal, toSameAxisOf: fontPopup)
    sizeCombo.autoPinEdge(.left, to: .right, of: fontPopup, withOffset: 5)

    linespacingTitle.autoPinEdge(
      toSuperviewEdge: .left,
      withInset: 18,
      relation: .greaterThanOrEqual
    )
    linespacingTitle.autoPinEdge(.right, to: .right, of: fontTitle)
    linespacingTitle.autoAlignAxis(.baseline, toSameAxisOf: linespacingField)

    linespacingField.autoPinEdge(.top, to: .bottom, of: sizeCombo, withOffset: 18)
    linespacingField.autoPinEdge(.left, to: .right, of: linespacingTitle, withOffset: 5)
    linespacingField.autoSetDimension(.width, toSize: 60)
    NotificationCenter.default.addObserver(
      forName: NSControl.textDidEndEditingNotification,
      object: linespacingField,
      queue: nil
    ) { [unowned self] _ in self.linespacingAction() }

    characterspacingTitle.autoPinEdge(
      toSuperviewEdge: .left,
      withInset: 18,
      relation: .greaterThanOrEqual
    )
    characterspacingTitle.autoPinEdge(.right, to: .right, of: linespacingTitle)
    characterspacingTitle.autoAlignAxis(.baseline, toSameAxisOf: characterspacingField)

    characterspacingField.autoPinEdge(.top, to: .bottom, of: linespacingField, withOffset: 18)
    characterspacingField.autoPinEdge(.left, to: .right, of: characterspacingTitle, withOffset: 5)
    characterspacingField.autoSetDimension(.width, toSize: 60)
    NotificationCenter.default.addObserver(
      forName: NSControl.textDidEndEditingNotification,
      object: characterspacingField,
      queue: nil
    ) { [unowned self] _ in self.characterspacingAction() }

    characterspacingInfo.autoPinEdge(.left, to: .left, of: characterspacingField)
    characterspacingInfo.autoPinEdge(.top, to: .bottom, of: characterspacingField, withOffset: 5)

    ligatureCheckbox.autoPinEdge(.top, to: .bottom, of: characterspacingInfo, withOffset: 18)
    ligatureCheckbox.autoPinEdge(.left, to: .right, of: fontTitle, withOffset: 5)

    previewScrollView.autoSetDimension(.height, toSize: 200, relation: .greaterThanOrEqual)
    previewScrollView.autoPinEdge(.top, to: .bottom, of: ligatureCheckbox, withOffset: 18)
    previewScrollView.autoPinEdge(toSuperviewEdge: .right, withInset: 18)
    previewScrollView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 18)
    previewScrollView.autoPinEdge(toSuperviewEdge: .left, withInset: 18)
  }

  private func updateViews() {
    if let familyName = self.font.familyName { self.fontPopup.selectItem(withTitle: familyName) }
    self.sizeCombo.stringValue = String(Int(self.font.pointSize))
    self.linespacingField.stringValue = String(format: "%.2f", self.linespacing)
    self.characterspacingField.stringValue = String(format: "%.2f", self.characterspacing)
    self.ligatureCheckbox.boolState = self.usesLigatures
    self.previewArea.font = self.font
    self.colorschemeCheckbox.boolState = self.usesColorscheme
    self.fileIconCheckbox.boolState = self.showsFileIcon

    if self.usesLigatures {
      self.previewArea.useAllLigatures(self)
    } else {
      self.previewArea.turnOffLigatures(self)
    }
  }
}

// MARK: - Actions
extension AppearancePref {

  @objc func usesColorschemeAction(_ sender: NSButton) {
    self.emit(.setUsesColorscheme(sender.boolState))
  }

  @objc func fileIconAction(_ sender: NSButton) {
    self.emit(.setShowsFileIcon(sender.boolState))
  }

  @objc func usesLigaturesAction(_ sender: NSButton) {
    self.emit(.setUsesLigatures(sender.boolState))
  }

  @objc func fontPopupAction(_ sender: NSPopUpButton) {
    guard let selectedItem = self.fontPopup.selectedItem else { return }
    guard selectedItem.title != self.font.familyName else { return }
    guard let newFont = NSFont(name: selectedItem.title, size: self.font.pointSize) else { return }

    self.emit(.setFont(newFont))
  }

  func comboBoxSelectionDidChange(_ notification: Notification) {
    guard (notification.object as! NSComboBox) === self.sizeCombo else { return }

    let newFontSize = self.cappedFontSize(Int(self.sizes[self.sizeCombo.indexOfSelectedItem]))
    let newFont = sharedFontManager.convert(self.font, toSize: newFontSize)

    self.emit(.setFont(newFont))
  }

  @objc func sizeComboBoxDidEnter(_ sender: AnyObject!) {
    let newFontSize = self.cappedFontSize(self.sizeCombo.integerValue)
    let newFont = sharedFontManager.convert(self.font, toSize: newFontSize)

    self.emit(.setFont(newFont))
  }

  func linespacingAction() {
    let newLinespacing = self.cappedLinespacing(self.linespacingField.floatValue)
    self.emit(.setLinespacing(newLinespacing))
  }

  private func cappedLinespacing(_ linespacing: Float) -> CGFloat {
    let cgfLinespacing = linespacing.cgf

    guard cgfLinespacing >= NvimView.minLinespacing else { return NvimView.defaultLinespacing }
    guard cgfLinespacing <= NvimView.maxLinespacing else { return NvimView.maxLinespacing }

    return cgfLinespacing
  }

  func characterspacingAction() {
    let newCharacterspacing = self.cappedCharacterspacing(self.characterspacingField.floatValue)
    self.emit(.setCharacterspacing(newCharacterspacing))
  }

  private func cappedCharacterspacing(_ characterspacing: Float) -> CGFloat {
    let cgfCharacterspacing = characterspacing.cgf

    guard cgfCharacterspacing >= 0.0 else { return NvimView.defaultCharacterspacing }

    return cgfCharacterspacing
  }


  private func cappedFontSize(_ size: Int) -> CGFloat {
    let cgfSize = size.cgf

    guard cgfSize >= NvimView.minFontSize else { return NvimView.defaultFont.pointSize }
    guard cgfSize <= NvimView.maxFontSize else { return NvimView.maxFontSize }

    return cgfSize
  }
}

private let sharedFontManager = NSFontManager.shared
