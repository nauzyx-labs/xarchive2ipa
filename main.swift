import Foundation

// MARK: - UI Helpers
enum Color {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let cyan = "\u{001B}[0;36m"
    static let green = "\u{001B}[0;32m"
    static let red = "\u{001B}[0;31m"
    static let yellow = "\u{001B}[1;33m"
}

func printHeader() {
    print("\(Color.cyan)\(Color.bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Color.reset)")
    print("\(Color.cyan)\(Color.bold)  Xcode Archive to IPA Extractor (Native)\(Color.reset)")
    print("\(Color.cyan)\(Color.bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Color.reset)")
}

func shell(_ command: String) -> String? {
    let process = Process()
    process.launchPath = "/bin/zsh"
    process.arguments = ["-c", command]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

func shellInteractive(_ command: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", command]
    
    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    
    // Connect to current terminal for fzf
    process.standardInput = FileHandle.standardInput
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return nil
    }
}

// MARK: - Core Logic

let archiveBase = NSString(string: "~/Library/Developer/Xcode/Archives").expandingTildeInPath
let fileManager = FileManager.default

printHeader()

guard fileManager.fileExists(atPath: archiveBase) else {
    print("\(Color.red)Error: Xcode Archives directory not found at:\(Color.reset)")
    print("   \(archiveBase)")
    exit(1)
}

// Check for fzf
let hasFzf = shell("command -v fzf") != nil
var selectedArchivePath: String = ""

if hasFzf {
    let fzfCmd = "ls -1r '\(archiveBase)' | fzf --prompt='Select Date: ' --height=15 --reverse --border --info=inline"
    guard let dateDir = shellInteractive(fzfCmd), !dateDir.isEmpty else {
        print("Cancelled.")
        exit(0)
    }
    
    let fullDatePath = "\(archiveBase)/\(dateDir)"
    let fzfArchiveCmd = "ls -1 '\(fullDatePath)' | grep '.xcarchive$' | fzf --prompt='Select Archive: ' --height=15 --reverse --border --info=inline"
    guard let archiveName = shellInteractive(fzfArchiveCmd), !archiveName.isEmpty else {
        print("Cancelled.")
        exit(0)
    }
    
    selectedArchivePath = "\(fullDatePath)/\(archiveName)"
} else {
    print("\(Color.yellow)Note: 'fzf' is not installed. Falling back to basic selection.\(Color.reset)")
    
    do {
        let dates = try fileManager.contentsOfDirectory(atPath: archiveBase).sorted().reversed()
        if dates.isEmpty {
            print("\(Color.red)No archives found.\(Color.reset)")
            exit(1)
        }
        
        print("\n\(Color.bold)Select Archive Date:\(Color.reset)")
        for (index, date) in dates.enumerated() {
            print("\(index + 1)) \(date)")
        }
        
        print("Select (1-\(dates.count)): ", terminator: "")
        guard let input = readLine(), let choice = Int(input), choice > 0, choice <= dates.count else {
            print("Invalid selection.")
            exit(1)
        }
        
        let dateDir = Array(dates)[choice - 1]
        let fullDatePath = "\(archiveBase)/\(dateDir)"
        
        let archives = try fileManager.contentsOfDirectory(atPath: fullDatePath).filter { $0.hasSuffix(".xcarchive") }
        if archives.isEmpty {
            print("\(Color.red)No .xcarchive files found in \(dateDir).\(Color.reset)")
            exit(1)
        }
        
        print("\n\(Color.bold)Select .xcarchive:\(Color.reset)")
        for (index, archive) in archives.enumerated() {
            print("\(index + 1)) \(archive)")
        }
        
        print("Select (1-\(archives.count)): ", terminator: "")
        guard let archInput = readLine(), let archChoice = Int(archInput), archChoice > 0, archChoice <= archives.count else {
            print("Invalid selection.")
            exit(1)
        }
        
        selectedArchivePath = "\(fullDatePath)/\(archives[archChoice - 1])"
    } catch {
        print("\(Color.red)Error reading archives: \(error.localizedDescription)\(Color.reset)")
        exit(1)
    }
}

// Locate the .app file
let appSearchPath = "\(selectedArchivePath)/Products/Applications"
do {
    let items = try fileManager.contentsOfDirectory(atPath: appSearchPath)
    guard let appFile = items.first(where: { $0.hasSuffix(".app") }) else {
        print("\(Color.red)Error: Could not find .app file inside the archive.\(Color.reset)")
        exit(1)
    }
    
    let appPath = "\(appSearchPath)/\(appFile)"
    let appName = (appFile as NSString).deletingPathExtension
    let dateDir = (selectedArchivePath as NSString).lastPathComponent
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HHmmss"
    let timestamp = dateFormatter.string(from: Date())
    let outputIpa = "\(appName)_\(dateDir)_\(timestamp).ipa"
    
    print("\n\(Color.cyan)Processing:\(Color.reset) \((selectedArchivePath as NSString).lastPathComponent)")
    print("\(Color.cyan)Extracting:\(Color.reset) \(appFile)")
    
    // Create temp directory
    let tempDir = "\(NSTemporaryDirectory())xarchive2ipa-\(UUID().uuidString)"
    let payloadDir = "\(tempDir)/Payload"
    try fileManager.createDirectory(atPath: payloadDir, withIntermediateDirectories: true)
    
    // Copy app
    let destAppPath = "\(payloadDir)/\(appFile)"
    let cpProcess = Process()
    cpProcess.launchPath = "/bin/cp"
    cpProcess.arguments = ["-R", appPath, destAppPath]
    cpProcess.launch()
    cpProcess.waitUntilExit()
    
    // Zip
    print("\(Color.cyan)Compressing to .ipa...\(Color.reset)")
    let zipProcess = Process()
    zipProcess.launchPath = "/usr/bin/zip"
    zipProcess.currentDirectoryPath = tempDir
    zipProcess.arguments = ["-r", "-y", "-q", "output.ipa", "Payload"]
    zipProcess.launch()
    zipProcess.waitUntilExit()
    
    // Move to current directory
    let finalPath = "\(fileManager.currentDirectoryPath)/\(outputIpa)"
    if fileManager.fileExists(atPath: finalPath) {
        try fileManager.removeItem(atPath: finalPath)
    }
    try fileManager.moveItem(atPath: "\(tempDir)/output.ipa", toPath: finalPath)
    
    // Cleanup
    try fileManager.removeItem(atPath: tempDir)
    
    print("\n\(Color.green)\(Color.bold)Success! IPA created successfully.\(Color.reset)")
    print("\(Color.bold)Location:\(Color.reset) \(finalPath)")
    print("\(Color.cyan)Created by github.com/xyzuan\(Color.reset)")
    print("\(Color.cyan)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Color.reset)")
    
} catch {
    print("\(Color.red)Error: \(error.localizedDescription)\(Color.reset)")
    exit(1)
}
