import Cocoa

/// UIVIewController to represent the Podfile editor
/// It's scope is keeping track of the user project,
/// handling / exposing tabs and providing a central
/// access place for mutable state within the Podfile
/// section of CocoaPods.app

class CPPodfileViewController: NSViewController, NSTabViewDelegate {

  var userProject:CPUserProject!
  dynamic var installAction: CPInstallAction!

  @IBOutlet weak var actionTitleLabel: NSTextField!
  @IBOutlet weak var documentIconContainer: NSView!
  var pluginCoordinator: CPPodfilePluginCoordinator!

  @IBOutlet var tabViewDelegate: CPTabViewDelegate!

  override func viewWillAppear() {

    // The userProject is DI'd in after viewDidLoad
    installAction = CPInstallAction(userProject: userProject, notify: true)

    // The view needs to be added to a window before we can use
    // the window to pull out to the document icon from the window

    guard
      let window = view.window as? CPModifiedDecorationsWindow,
      let documentIcon = window.documentIconButton else {
        return print("Window type is not CPModifiedDecorationsWindow")
    }

    // Grab the document icon and move it into the space on our 
    // custom title bar
    documentIcon.frame = documentIcon.bounds
    documentIconContainer.addSubview(documentIcon)

    // Default the bottom label to hidden
    hideWarningLabel(false)

    // Check for whether we need to install plugins
    pluginCoordinator = CPPodfilePluginCoordinator(controller: self)
    pluginCoordinator.comparePluginsWithinUserProject(userProject)

    // Makes the tabs highlight correctly
    tabController.hiddenTabDelegate = tabViewDelegate

    // When integrating into one xcodeproj
    // we should show "Podfile for ProjectName" instead
    userProject.registerForFullMetadataCallback {
      guard let targets = self.userProject.xcodeIntegrationDictionary["projects"] as? [String:AnyObject] else { return }
      if targets.keys.count == 1 {
        let project = targets.keys.first!
        let url = NSURL(fileURLWithPath: project)
        let name = url.lastPathComponent!.stringByReplacingOccurrencesOfString(".xcproj", withString: "")
        self.actionTitleLabel.stringValue = "Podfile for \(name)"
      }
    }
  }

  var tabController: CPHiddenTabViewController {
    return childViewControllers.filter { $0.isKindOfClass(CPHiddenTabViewController) }.first! as! CPHiddenTabViewController
  }

  @IBAction func install(obj: AnyObject) {
    installAction.performAction(.Install(verbose: false))
    showConsoleTab(self)
  }

  @IBAction func installVerbose(obj: AnyObject) {
    installAction.performAction(.Install(verbose: true))
    showConsoleTab(self)
  }

  @IBAction func installUpdate(obj: AnyObject) {
    installAction.performAction(.Update(verbose: false))
    showConsoleTab(self)
  }

  @IBAction func installUpdateVerbose(obj: AnyObject) {
    installAction.performAction(.Update(verbose: true))
    showConsoleTab(self)
  }

  @IBOutlet var installMenu: NSMenu!
  @IBAction func showInstallOptions(button: NSButton) {
    guard let event = NSApp.currentEvent else { return }
    NSMenu.popUpContextMenu(installMenu, withEvent: event, forView: button)
  }


  @IBAction func showEditorTab(sender: AnyObject) {
    tabController.selectedTabViewItemIndex = 0
  }

  @IBAction func showConsoleTab(sender: AnyObject) {
    tabController.selectedTabViewItemIndex = 2
  }

  @IBAction func showInformationTab(sender: AnyObject) {
    tabController.selectedTabViewItemIndex = 1
  }

  @IBOutlet weak var warningDoneButton: NSButton!
  @IBOutlet weak var warningLabel: NSTextField!
  @IBOutlet weak var warningLabelHeight: NSLayoutConstraint!

  func showWarningLabelWithSender(message: String, actionTitle:String, target: AnyObject?, action: Selector, animated:Bool) {
    view.layoutSubtreeIfNeeded()

    let label = animated ? warningLabelHeight.animator() : warningLabelHeight
    label.constant = 50

    warningLabel.stringValue = message
    warningDoneButton.title = actionTitle
    warningDoneButton.target = target
    warningDoneButton.action = action
    warningDoneButton.enabled = true
  }

  func hideWarningLabel(animated:Bool = true) {
    view.layoutSubtreeIfNeeded()
    let label = animated ? warningLabelHeight.animator() : warningLabelHeight
    label.constant = 0
    warningDoneButton.enabled = false
  }

}

extension NSViewController {

  /// Recurse the parentViewControllers till we find a CPPodfileViewController
  /// this lets child view controllers access this class for shared state.

  var podfileViewController: CPPodfileViewController? {

    guard let parent = self.parentViewController else { return nil }
    if let appVC = parent as? CPPodfileViewController {
      return appVC
    } else {
      return parent.podfileViewController
    }
  }
}
