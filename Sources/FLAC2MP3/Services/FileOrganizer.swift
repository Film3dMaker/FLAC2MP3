import Foundation

public struct CollectedFLAC {
    public let url: URL
    public let rootFolderURL: URL?
    public let rootFolderName: String?
    public let relativePath: String

    public init(
        url: URL,
        rootFolderURL: URL? = nil,
        rootFolderName: String? = nil,
        relativePath: String
    ) {
        self.url = url
        self.rootFolderURL = rootFolderURL
        self.rootFolderName = rootFolderName
        self.relativePath = relativePath
    }
}

public struct FileOrganizer {
    public static func collectFiles(
        from urls: [URL],
        recursive: Bool
    ) -> (flacFiles: [CollectedFLAC], extraFiles: [ExtraFileItem]) {
        var flacFiles: [CollectedFLAC] = []
        var extraFiles: [ExtraFileItem] = []
        var seenFLACPaths = Set<String>()
        var seenExtraPaths = Set<String>()

        for rootURL in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                let folderName = rootURL.lastPathComponent
                let enumerator: FileManager.DirectoryEnumerator?
                if recursive {
                    enumerator = FileManager.default.enumerator(
                        at: rootURL,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    )
                } else {
                    enumerator = FileManager.default.enumerator(
                        at: rootURL,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                    )
                }

                while let fileURL = enumerator?.nextObject() as? URL {
                    var isFileDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isFileDir),
                          !isFileDir.boolValue else { continue }

                    if FileParser.isFLAC(fileURL) {
                        if !seenFLACPaths.contains(fileURL.path) {
                            seenFLACPaths.insert(fileURL.path)
                            let relativePath = getRelativePath(fileURL, baseURL: rootURL)
                            flacFiles.append(CollectedFLAC(
                                url: fileURL,
                                rootFolderURL: rootURL,
                                rootFolderName: folderName,
                                relativePath: relativePath
                            ))
                        }
                    } else if FileParser.isExtraFile(fileURL) {
                        if !seenExtraPaths.contains(fileURL.path) {
                            seenExtraPaths.insert(fileURL.path)
                            let relativePath = getRelativePath(fileURL, baseURL: rootURL)
                            extraFiles.append(ExtraFileItem(
                                sourceURL: fileURL,
                                rootFolderURL: rootURL,
                                rootFolderName: folderName,
                                relativePath: relativePath
                            ))
                        }
                    }
                }
            } else {
                // Single file dropped
                if FileParser.isFLAC(rootURL) {
                    if !seenFLACPaths.contains(rootURL.path) {
                        seenFLACPaths.insert(rootURL.path)
                        flacFiles.append(CollectedFLAC(
                            url: rootURL,
                            rootFolderURL: nil,
                            rootFolderName: nil,
                            relativePath: rootURL.lastPathComponent
                        ))
                    }
                } else if FileParser.isExtraFile(rootURL) {
                    if !seenExtraPaths.contains(rootURL.path) {
                        seenExtraPaths.insert(rootURL.path)
                        extraFiles.append(ExtraFileItem(
                            sourceURL: rootURL,
                            rootFolderURL: nil,
                            rootFolderName: nil,
                            relativePath: rootURL.lastPathComponent
                        ))
                    }
                }
            }
        }

        // Natural sort files by relativePath/filename
        flacFiles.sort { lhs, rhs in
            lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }

        return (flacFiles, extraFiles)
    }

    public static func getRelativePath(_ url: URL, baseURL: URL) -> String {
        let basePath = baseURL.path.hasSuffix("/") ? baseURL.path : baseURL.path + "/"
        let fullPath = url.path
        if fullPath.hasPrefix(basePath) {
            return String(fullPath.dropFirst(basePath.count))
        }
        return url.lastPathComponent
    }
}