import SwiftUI
import AppKit

public struct FileListView: View {
    @ObservedObject public var viewModel: MainViewModel

    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 10) {
            // CleanMyMac Style Header Summary Pill
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "music.note.list")
                        .foregroundColor(Color(red: 0.15, green: 0.55, blue: 1.0))
                        .font(.system(size: 15, weight: .bold))

                    Text("Cola de Conversión")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("\(viewModel.tasks.count) pistas")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    if !viewModel.extraFiles.isEmpty {
                        Text("+ \(viewModel.extraFiles.count) adjuntos")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .foregroundColor(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }

                Spacer()

                if !viewModel.isProcessing {
                    if viewModel.completedCount > 0 {
                        Button {
                            viewModel.clearCompleted()
                        } label: {
                            Text("Limpiar completados")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        viewModel.reset()
                    } label: {
                        Text("Vaciar lista")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }


            }
            .padding(.horizontal, 4)

            // Scrollable List Container with Frosted Glass Surface
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.tasks) { task in
                        FileRowView(
                            task: task,
                            onRemove: {
                                viewModel.removeTask(id: task.id)
                            },
                            onReveal: {
                                if let outURL = task.outputURL, FileManager.default.fileExists(atPath: outURL.path) {
                                    NSWorkspace.shared.activateFileViewerSelecting([outURL])
                                } else {
                                    NSWorkspace.shared.activateFileViewerSelecting([task.sourceURL])
                                }
                            }
                        )
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

public struct FileRowView: View {
    public let task: ConversionTask
    public var onRemove: () -> Void
    public var onReveal: () -> Void

    @State private var isHovered = false

    public init(
        task: ConversionTask,
        onRemove: @escaping () -> Void = {},
        onReveal: @escaping () -> Void = {}
    ) {
        self.task = task
        self.onRemove = onRemove
        self.onReveal = onReveal
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 14) {
            trackArtwork

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if let album = task.rootFolderName, !album.isEmpty {
                        Text(album)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.primary.opacity(0.06))
                            .foregroundColor(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }

                    if let meta = task.metadata, meta.trackNumber > 0 {
                        Text(String(format: "%02d", meta.trackNumber))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Text(task.sourceFileName)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if !task.formattedFileSize.isEmpty {
                        Text(task.formattedFileSize)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.75))
                    }
                }

                if let meta = task.metadata, meta.isComplete {
                    Text("\(meta.artist)  —  \(meta.album)")
                        .font(.system(size: 13.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let error = task.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .lineLimit(1)
                } else {
                    Text(task.relativePath)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }


            Spacer()

            if isHovered && task.status != .converting && task.status != .recognizing {
                Button(action: onReveal) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Mostrar en Finder")

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Eliminar")
            }

            statusBadge
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.08) : Color(NSColor.windowBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isHovered
                            ? [Color.white.opacity(0.35), Color.white.opacity(0.1)]
                            : [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.02), radius: isHovered ? 8 : 2, x: 0, y: isHovered ? 4 : 1)
        .scaleEffect(isHovered ? 1.003 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Mostrar en Finder", action: onReveal)
            Button("Eliminar de la lista", action: onRemove)
        }

    }

    @ViewBuilder
    private var trackArtwork: some View {
        if let coverURL = task.metadata?.coverImageURL,
           let image = NSImage(contentsOf: coverURL) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
        } else if let data = task.metadata?.coverImageData,
                  let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
        } else {
            statusIcon
                .frame(width: 28, height: 28)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 17))
                .foregroundColor(.secondary.opacity(0.5))
        case .readingMetadata:
            Image(systemName: "tag.fill")
                .font(.system(size: 17))
                .foregroundColor(.indigo)
        case .recognizing:
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 17))
                .foregroundColor(.orange)
        case .converting:
            ProgressView()
                .scaleEffect(0.75)
                .frame(width: 22, height: 22)
        case .copying:
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 17))
                .foregroundColor(.blue)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 19))
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 19))
                .foregroundColor(.red)
        case .cancelled:
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 19))
                .foregroundColor(.orange)
        }
    }

    private var statusBadge: some View {
        Text(task.status.rawValue)
            .font(.system(size: 12.5, weight: .bold, design: .rounded))
            .padding(.horizontal, 9)
            .padding(.vertical, 3.5)
            .background(statusColor(task.status).opacity(0.12))
            .foregroundColor(statusColor(task.status))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }



    private func statusColor(_ status: ConversionStatus) -> Color {
        switch status {
        case .pending:
            return .secondary
        case .readingMetadata:
            return .indigo
        case .recognizing:
            return .orange
        case .converting:
            return .blue
        case .copying:
            return .teal
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        }
    }
}

