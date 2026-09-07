import Foundation
import SwiftUI
import AppKit

@MainActor
public class MainViewModel: ObservableObject {
    @Published public var tasks: [ConversionTask] = []
    @Published public var extraFiles: [ExtraFileItem] = []
    @Published public var isProcessing = false
    @Published public var overallProgress: Double = 0
    @Published public var completedCount = 0
    @Published public var totalCount = 0
    @Published public var failCount = 0
    @Published public var statusMessage = ""
    @Published public var sourceFolderURL: URL?
    @Published public var outputFolderURL: URL?
    @Published public var isCancelled = false
    @Published public var isFFmpegMissing = false

    public let settings = AppSettings()


    private var recognizer: AudioRecognizer?

    public init() {
        checkDependencies()
    }

    public func checkDependencies() {
        isFFmpegMissing = !FFmpegConverter.isFFmpegAvailable
    }

    public var outputExtension: String {
        settings.outputFormat.fileExtension
    }

    public var resolvedOutputFolderURL: URL? {
        switch settings.destinationMode {
        case .subfolderMP3:
            let folderName = settings.outputFolderName.isEmpty ? "MP3" : settings.outputFolderName
            if let source = sourceFolderURL {
                return source.appendingPathComponent(folderName)
            } else if let firstTask = tasks.first {
                return firstTask.sourceURL.deletingLastPathComponent().appendingPathComponent(folderName)
            }
            return nil

        case .customFolder:
            if !settings.customOutputFolderPath.isEmpty {
                return URL(fileURLWithPath: settings.customOutputFolderPath)
            }
            return nil

        case .sameAsSource:
            return sourceFolderURL ?? tasks.first?.sourceURL.deletingLastPathComponent()
        }
    }

    public func loadURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        if urls.count == 1 && urls[0].hasDirectoryPath {
            sourceFolderURL = urls[0]
        } else {
            sourceFolderURL = urls.first?.deletingLastPathComponent()
        }

        let (flacFiles, extras) = FileOrganizer.collectFiles(from: urls, recursive: settings.recursive)

        let targetFolder = resolvedOutputFolderURL

        let newTasks = flacFiles.map { item -> ConversionTask in
            let outURL = computeOutputURL(
                for: item.url,
                rootFolderURL: item.rootFolderURL,
                rootFolderName: item.rootFolderName,
                relativePath: item.relativePath
            )

            // Extract instant metadata from filename + local cover art search
            var meta = FileParser.parseFilename(item.url)

            let parent = item.url.deletingLastPathComponent()
            let coverNames = ["cover.jpg", "folder.jpg", "front.jpg", "cover.png", "folder.png", "front.png", "artwork.jpg", "AlbumArtSmall.jpg"]
            for name in coverNames {
                let candidate = parent.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    meta.coverImageURL = candidate
                    break
                }
            }

            return ConversionTask(
                sourceURL: item.url,
                rootFolderURL: item.rootFolderURL,
                rootFolderName: item.rootFolderName,
                relativePath: item.relativePath,
                outputURL: outURL,
                metadata: meta
            )
        }


        self.tasks = newTasks
        self.extraFiles = extras
        self.totalCount = newTasks.count
        self.completedCount = 0
        self.failCount = 0
        self.overallProgress = 0
        self.outputFolderURL = targetFolder
        self.statusMessage = "\(newTasks.count) archivo(s) FLAC listo(s) para convertir"
    }

    public func loadFolder(_ url: URL) {
        loadURLs([url])
    }

    public func computeOutputURL(
        for sourceURL: URL,
        rootFolderURL: URL?,
        rootFolderName: String?,
        relativePath: String
    ) -> URL {
        let filenameWithoutExt = sourceURL.deletingPathExtension().lastPathComponent
        let newFilename = filenameWithoutExt + ".mp3"

        switch settings.destinationMode {
        case .subfolderMP3:
            let parentDir = sourceURL.deletingLastPathComponent()
            let subfolderName = settings.outputFolderName.isEmpty ? "MP3" : settings.outputFolderName
            let mp3Subfolder = parentDir.appendingPathComponent(subfolderName)
            return mp3Subfolder.appendingPathComponent(newFilename)

        case .customFolder:
            let customDir: URL
            if !settings.customOutputFolderPath.isEmpty {
                customDir = URL(fileURLWithPath: settings.customOutputFolderPath)
            } else {
                customDir = sourceURL.deletingLastPathComponent()
            }

            let relativeClean = (relativePath as NSString).deletingPathExtension + ".mp3"

            // When a root folder was dragged/loaded (e.g. from Downloads/Album1), preserve its album folder name
            if let albumFolder = rootFolderName, !albumFolder.isEmpty {
                return customDir.appendingPathComponent(albumFolder).appendingPathComponent(relativeClean)
            } else {
                return customDir.appendingPathComponent(relativeClean)
            }

        case .sameAsSource:
            return sourceURL.deletingLastPathComponent().appendingPathComponent(newFilename)
        }
    }

    public func updateDestinations() {
        for i in tasks.indices {
            tasks[i].outputURL = computeOutputURL(
                for: tasks[i].sourceURL,
                rootFolderURL: tasks[i].rootFolderURL,
                rootFolderName: tasks[i].rootFolderName,
                relativePath: tasks[i].relativePath
            )
        }
        self.outputFolderURL = resolvedOutputFolderURL
    }


    // MARK: - Parallel Conversion Execution
    public func startConversion() async {
        guard !tasks.isEmpty else { return }
        checkDependencies()
        guard !isFFmpegMissing else {
            statusMessage = "Error: FFmpeg no está instalado en el sistema."
            return
        }

        isProcessing = true
        isCancelled = false
        completedCount = 0
        failCount = 0
        overallProgress = 0

        updateDestinations()

        let recognizer = AudioRecognizer()
        self.recognizer = recognizer
        let converter = FFmpegConverter.shared
        converter.reset()
        recognizer.reset()

        // Reset tasks state before starting
        for i in tasks.indices {
            tasks[i].status = .pending
            tasks[i].errorMessage = nil
            tasks[i].progress = 0
        }

        let maxConcurrent = max(1, min(8, settings.concurrencyThreads))
        let total = tasks.count

        // Process tasks with bounded parallelism
        var taskIndices = Array(tasks.indices)

        await withTaskGroup(of: (index: Int, success: Bool, errorMsg: String?).self) { group in
            let initialBatch = min(maxConcurrent, taskIndices.count)
            for _ in 0..<initialBatch {
                if !taskIndices.isEmpty {
                    let idx = taskIndices.removeFirst()
                    group.addTask {
                        let (success, errorMsg) = await self.processSingleTask(
                            index: idx,
                            recognizer: recognizer,
                            converter: converter
                        )
                        return (idx, success, errorMsg)
                    }
                }
            }

            for await (_, success, _) in group {
                if success {
                    self.completedCount += 1
                } else if !self.isCancelled {
                    self.failCount += 1
                }

                let done = self.completedCount + self.failCount
                self.overallProgress = total > 0 ? Double(done) / Double(total) : 0
                self.statusMessage = "\(done) de \(total) procesados (\(self.completedCount) listos, \(self.failCount) errores)"

                if !taskIndices.isEmpty && !self.isCancelled {
                    let nextIdx = taskIndices.removeFirst()
                    group.addTask {
                        let (s, e) = await self.processSingleTask(
                            index: nextIdx,
                            recognizer: recognizer,
                            converter: converter
                        )
                        return (nextIdx, s, e)
                    }
                }
            }
        }


        // Copy extra files if enabled
        if settings.copyExtraFiles && !isCancelled && !extraFiles.isEmpty {
            statusMessage = "Copiando archivos adicionales (.jpg, .cue, .log, .m3u)..."
            copyExtraFiles()
        }



        self.recognizer = nil
        self.isProcessing = false

        if isCancelled {
            statusMessage = "Conversión cancelada (\(completedCount) completados)"
        } else {
            statusMessage = "Completado: \(completedCount) exitosos" + (failCount > 0 ? ", \(failCount) errores" : "")
            NSSound(named: "Glass")?.play()
            if settings.showNotifications {
                NotificationService.sendCompletionNotification(
                    successCount: completedCount,
                    failCount: failCount,
                    totalCount: totalCount
                )
            }
        }

    }

    private func processSingleTask(
        index: Int,
        recognizer: AudioRecognizer,
        converter: FFmpegConverter
    ) async -> (Bool, String?) {
        guard index < tasks.count else { return (false, "Índice fuera de rango") }
        let sourceURL = tasks[index].sourceURL
        guard let outputURL = tasks[index].outputURL else {
            await MainActor.run {
                tasks[index].status = .failed
                tasks[index].errorMessage = "URL de salida no válida"
            }
            return (false, "URL de salida no válida")
        }

        if isCancelled {
            await MainActor.run { tasks[index].status = .cancelled }
            return (false, "Cancelado")
        }

        // Step 1: Metadata Recognition
        await MainActor.run {
            tasks[index].status = .recognizing
        }

        let metadata = await recognizer.recognize(url: sourceURL, mode: settings.recognitionMode)

        await MainActor.run {
            tasks[index].metadata = metadata
            tasks[index].status = .converting
        }

        if isCancelled {
            await MainActor.run { tasks[index].status = .cancelled }
            return (false, "Cancelado")
        }

        // Step 2: Conversion
        do {
            try await converter.convert(
                sourceURL: sourceURL,
                outputURL: outputURL,
                format: settings.outputFormat,
                bitrate: settings.bitrate,
                metadata: metadata
            )

            await MainActor.run {
                tasks[index].status = .completed
                tasks[index].progress = 1.0
            }
            return (true, nil)
        } catch let error as ConversionError {
            await MainActor.run {
                if case .cancelled = error {
                    tasks[index].status = .cancelled
                } else {
                    tasks[index].status = .failed
                    tasks[index].errorMessage = error.localizedDescription
                }
            }
            return (false, error.localizedDescription)
        } catch {
            await MainActor.run {
                tasks[index].status = .failed
                tasks[index].errorMessage = error.localizedDescription
            }
            return (false, error.localizedDescription)
        }
    }

    public func cancelConversion() {
        isCancelled = true
        recognizer?.cancel()
        FFmpegConverter.shared.cancel()
        for i in tasks.indices {
            if tasks[i].status == .converting || tasks[i].status == .recognizing || tasks[i].status == .pending {
                tasks[i].status = .cancelled
            }
        }
    }

    public func retryFailed() {
        guard !isProcessing else { return }
        for i in tasks.indices {
            if tasks[i].status == .failed || tasks[i].status == .cancelled {
                tasks[i].status = .pending
                tasks[i].errorMessage = nil
                tasks[i].progress = 0
            }
        }
        Task {
            await startConversion()
        }
    }

    public func clearCompleted() {
        tasks.removeAll { $0.status == .completed }
        totalCount = tasks.count
        completedCount = 0
        failCount = 0
        overallProgress = 0
        statusMessage = "\(tasks.count) archivo(s) restante(s)"
    }

    public func removeTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        totalCount = tasks.count
        completedCount = tasks.filter { $0.status == .completed }.count
        failCount = tasks.filter { $0.status == .failed }.count
        overallProgress = totalCount > 0 ? Double(completedCount + failCount) / Double(totalCount) : 0
    }

    public func reset() {
        tasks = []
        extraFiles = []
        isProcessing = false
        overallProgress = 0
        completedCount = 0
        totalCount = 0
        failCount = 0
        statusMessage = ""
        sourceFolderURL = nil
        outputFolderURL = nil
        isCancelled = false
        recognizer = nil
    }

    public func openOutputFolderInFinder() {
        if let folder = resolvedOutputFolderURL {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        }
    }

    private func copyExtraFiles() {
        guard settings.copyExtraFiles else { return }

        for item in extraFiles {
            let destURL: URL

            switch settings.destinationMode {
            case .subfolderMP3:
                let subfolderName = settings.outputFolderName.isEmpty ? "MP3" : settings.outputFolderName
                let parentDir = item.sourceURL.deletingLastPathComponent()
                destURL = parentDir.appendingPathComponent(subfolderName).appendingPathComponent(item.sourceURL.lastPathComponent)

            case .customFolder:
                guard !settings.customOutputFolderPath.isEmpty else { continue }
                let customDir = URL(fileURLWithPath: settings.customOutputFolderPath)
                if let albumFolder = item.rootFolderName, !albumFolder.isEmpty {
                    destURL = customDir.appendingPathComponent(albumFolder).appendingPathComponent(item.relativePath)
                } else {
                    destURL = customDir.appendingPathComponent(item.relativePath)
                }

            case .sameAsSource:
                // Extra files are already in the source directory alongside the FLAC files
                continue
            }

            let destDir = destURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: item.sourceURL, to: destURL)
            } catch {
                print("Error copying extra file \(item.sourceURL.lastPathComponent): \(error)")
            }
        }
    }
}


