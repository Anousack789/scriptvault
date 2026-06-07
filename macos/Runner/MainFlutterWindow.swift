import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    setupSavePanelChannel(flutterViewController)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  private func setupSavePanelChannel(_ flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "scriptvault/save_panel",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      guard call.method == "chooseOutputPath" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let arguments = call.arguments as? [String: Any]
      let defaultName = arguments?["defaultName"] as? String ?? "script-output.txt"
      let panel = NSSavePanel()
      panel.canCreateDirectories = true
      panel.nameFieldStringValue = defaultName
      panel.allowedFileTypes = ["txt"]

      let response = panel.runModal()
      result(response == .OK ? panel.url?.path : nil)
    }
  }
}
