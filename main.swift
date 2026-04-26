import Foundation

// MARK: - UI Helpers
enum Color {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let cyan = "\u{001B}[0;36m"
    static let green = "\u{001B}[0;32m"
    static let red = "\u{001B}[0;31m"
    static let yellow = "\u{001B}[1;33m"
    static let gray = "\u{001B}[0;90m"
}

func printHeader() {
    print("\(Color.cyan)\(Color.bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Color.reset)")
    print("\(Color.cyan)\(Color.bold)  Xcode Archive to IPA\(Color.reset)")
    print("\(Color.cyan)GitHub: https://github.com/xyzuan\(Color.reset)")
    print("\(Color.cyan)\(Color.bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Color.reset)")
}

// MARK: - Selector

func nativeSelect(items: [String], prompt: String) -> String? {
    if items.count == 1 {
        print("\(Color.green)Auto-selecting:\(Color.reset) \(items[0])")
        return items[0]
    }

    print("\n\(Color.bold)\(prompt)\(Color.reset)")
    for (index, item) in items.enumerated() {
        let num = String(format: "%2d", index + 1)
        print("  \(Color.cyan)\(num))\(Color.reset) \(item)")
    }
    
    while true {
        print("\n\(Color.bold)Select (1-\(items.count)) or 'q' to quit: \(Color.reset)", terminator: "")
        fflush(stdout)
        
        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        
        if input.lowercased() == "q" { return nil }
        
        if let choice = Int(input), choice > 0, choice <= items.count {
            return items[choice - 1]
        }
        
        print("\(Color.red)Invalid selection. Please enter a number between 1 and \(items.count).\(Color.reset)")
    }
}

// MARK: - Main Execution

let archiveBase = NSString(string: "~/Library/Developer/Xcode/Archives").expandingTildeInPath
let fileManager = FileManager.default

printHeader()

guard fileManager.fileExists(atPath: archiveBase) else {
    print("\(Color.red)Error: Archives directory not found.\(Color.reset)")
    exit(1)
}

do {
    // 1. Select Date
    let contents = try fileManager.contentsOfDirectory(atPath: archiveBase)
    let dateDirs = contents.filter { !($0.hasPrefix(".")) }.sorted().reversed()
    
    if dateDirs.isEmpty {
        print("\(Color.red)No archives found.\(Color.reset)")
        exit(1)
    }

    guard let selectedDate = nativeSelect(items: Array(dateDirs), prompt: "Select Archive Date:") else {
        print("Cancelled.")
        exit(0)
    }
    
    // 2. Select Archive
    let fullDatePath = "\(archiveBase)/\(selectedDate)"
    let archives = try fileManager.contentsOfDirectory(atPath: fullDatePath)
        .filter { $0.hasSuffix(".xcarchive") }
        .sorted().reversed()
        
    if archives.isEmpty {
        print("\(Color.red)No .xcarchive files found in \(selectedDate).\(Color.reset)")
        exit(1)
    }
    
    guard let selectedArchive = nativeSelect(items: Array(archives), prompt: "Select .xcarchive:") else {
        print("Cancelled.")
        exit(0)
    }
    
    let fullArchivePath = "\(fullDatePath)/\(selectedArchive)"
    
    // 3. Extract .app
    let appSearchPath = "\(fullArchivePath)/Products/Applications"
    let appFiles = try fileManager.contentsOfDirectory(atPath: appSearchPath).filter { $0.hasSuffix(".app") }
    
    guard let appFile = appFiles.first else {
        print("\(Color.red)Error: Could not find .app file inside the archive.\(Color.reset)")
        exit(1)
    }
    
    let appPath = "\(appSearchPath)/\(appFile)"
    let appName = (appFile as NSString).deletingPathExtension
    let dateStr = (selectedDate as NSString).lastPathComponent
    let df = DateFormatter()
    df.dateFormat = "HHmmss"
    let timestamp = df.string(from: Date())
    let outputIpa = "\(appName)_\(dateStr)_\(timestamp).ipa"
    
    print("\n\(Color.cyan)Processing:\(Color.reset) \(selectedArchive)")
    print("\(Color.cyan)Extracting:\(Color.reset) \(appFile)")
    
    // 4. Packaging
    let tempDir = "\(NSTemporaryDirectory())x2i-\(UUID().uuidString)"
    let payloadDir = "\(tempDir)/Payload"
    try fileManager.createDirectory(atPath: payloadDir, withIntermediateDirectories: true)
    
    let cpProcess = Process()
    cpProcess.launchPath = "/bin/cp"
    cpProcess.arguments = ["-R", appPath, "\(payloadDir)/"]
    try? cpProcess.run()
    cpProcess.waitUntilExit()
    
    print("\(Color.cyan)Compressing to .ipa...\(Color.reset)")
    let zipProcess = Process()
    zipProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
    zipProcess.arguments = ["-c", "cd \"\(tempDir)\" && /usr/bin/zip -r -y -q \"output.ipa\" Payload"]
    try? zipProcess.run()
    zipProcess.waitUntilExit()
    
    let finalPath = "\(fileManager.currentDirectoryPath)/\(outputIpa)"
    if fileManager.fileExists(atPath: finalPath) {
        try fileManager.removeItem(atPath: finalPath)
    }
    try fileManager.moveItem(atPath: "\(tempDir)/output.ipa", toPath: finalPath)
    try? fileManager.removeItem(atPath: tempDir)
    
    print("\n\(Color.green)\(Color.bold)Success! IPA created successfully.\(Color.reset)")
    print("\(Color.bold)Location:\(Color.reset) \(finalPath)")
    print("\(Color.cyan)Created by github.com/xyzuan\(Color.reset)")
    print("\(Color.cyan)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Color.reset)")
    
} catch {
    print("\(Color.red)Error: \(error.localizedDescription)\(Color.reset)")
    exit(1)
}
