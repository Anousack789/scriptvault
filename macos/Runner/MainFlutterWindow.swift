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
      if call.method == "chooseOutputPath" {
        self.chooseOutputPath(call, result)
        return
      }

      if call.method == "chooseStorageDirectory" {
        self.chooseStorageDirectory(result)
        return
      }

      if call.method == "chooseVaultExportPath" {
        self.chooseVaultExportPath(result)
        return
      }

      if call.method == "chooseVaultImportFile" {
        self.chooseVaultImportFile(result)
        return
      }

      if call.method == "chooseScriptFile" {
        self.chooseScriptFile(result)
        return
      }

      result(FlutterMethodNotImplemented)
    }
  }

  private func chooseOutputPath(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    let defaultName = arguments?["defaultName"] as? String ?? "script-output.txt"
    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = defaultName
    panel.allowedFileTypes = ["txt"]

    let response = panel.runModal()
    result(response == .OK ? panel.url?.path : nil)
  }

  private func chooseStorageDirectory(_ result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false

    let response = panel.runModal()
    result(response == .OK ? panel.url?.path : nil)
  }

  private func chooseVaultExportPath(_ result: @escaping FlutterResult) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"

    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = "scriptvault-export-\(formatter.string(from: Date())).scriptvault"
    panel.allowedFileTypes = ["scriptvault"]

    let response = panel.runModal()
    result(response == .OK ? panel.url?.path : nil)
  }

  private func chooseVaultImportFile(_ result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedFileTypes = ["scriptvault"]

    let response = panel.runModal()
    result(response == .OK ? panel.url?.path : nil)
  }

  private func chooseScriptFile(_ result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedFileTypes = ["sh", "bash", "zsh", "command", "tool", "txt"]

    let response = panel.runModal()
    result(response == .OK ? panel.url?.path : nil)
  }
}
