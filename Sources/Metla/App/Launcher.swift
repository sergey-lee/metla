import SwiftUI

@main
enum Launcher {
    @MainActor
    static func main() {
        DatalessPolicy.disableMaterialization()
        ScanSettings.registerDefaults()
        AppLanguage.applyLayoutDirection()
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let index = arguments.firstIndex(of: "--cli") {
            CommandLineTool.run(Array(arguments[(index + 1)...]))
        } else {
            MetlaApp.main()
        }
    }
}
