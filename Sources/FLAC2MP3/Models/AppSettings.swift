import Foundation
import SwiftUI

public class AppSettings: ObservableObject {

    @AppStorage("outputFormat") public var outputFormat: OutputFormat = .mp3
    @AppStorage("bitrate") public var bitrate: Bitrate = .b320
    @AppStorage("copyExtraFiles") public var copyExtraFiles: Bool = true
    @AppStorage("recursive") public var recursive: Bool = true
    @AppStorage("recognitionMode") public var recognitionMode: RecognitionMode = .hybrid
    @AppStorage("destinationMode") public var destinationMode: OutputDestinationMode = .subfolderMP3
    @AppStorage("outputFolderName") public var outputFolderName: String = "MP3"
    @AppStorage("customOutputFolderPath") public var customOutputFolderPath: String = ""
    @AppStorage("concurrencyThreads") public var concurrencyThreads: Int = min(8, max(2, ProcessInfo.processInfo.activeProcessorCount))
    @AppStorage("overwriteExisting") public var overwriteExisting: Bool = true
    @AppStorage("showNotifications") public var showNotifications: Bool = true
    @AppStorage("language") public var language: String = "es"

    public init() {}
}


