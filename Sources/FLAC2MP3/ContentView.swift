import SwiftUI
import AppKit

public struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var copiedCommand = false

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            headerView

            if viewModel.isFFmpegMissing {
                dependencyWarningBanner
            }

            // Central Stage (Fills all vertical space dynamically)
            ZStack {
                if viewModel.tasks.isEmpty {
                    DropZoneView(viewModel: viewModel)
                } else {
                    FileListView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom Pinned Controls + CleanMyMac Action Dock
            VStack(spacing: 10) {
                SettingsPanel(
                    settings: viewModel.settings,
                    outputFolderURL: viewModel.resolvedOutputFolderURL,
                    sourceFolderURL: viewModel.sourceFolderURL,
                    onDestinationChanged: {
                        viewModel.updateDestinations()
                    }
                )

                ProgressSection(viewModel: viewModel)
            }
        }
        .padding(18)
        .frame(minWidth: 860, idealWidth: 940, minHeight: 640, idealHeight: 720)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor)

                // CleanMyMac Atmospheric Mesh Lighting (Sapphire & Sunset Glows)
                RadialGradient(
                    colors: [
                        Color(red: 0.1, green: 0.5, blue: 1.0).opacity(0.18),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 40,
                    endRadius: 650
                )

                RadialGradient(
                    colors: [
                        Color(red: 0.95, green: 0.35, blue: 0.6).opacity(0.12),
                        Color.clear
                    ],
                    center: .bottomTrailing,
                    startRadius: 40,
                    endRadius: 600
                )
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .init("LoadURLs"))) { notification in
            if let urls = notification.object as? [URL] {
                viewModel.loadURLs(urls)
            } else if let url = notification.object as? URL {
                viewModel.loadURLs([url])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("LoadFolder"))) { notification in
            if let url = notification.object as? URL {
                viewModel.loadURLs([url])
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            // Glowing App Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.55, blue: 1.0),
                                Color(red: 0.05, green: 0.35, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: Color(red: 0.05, green: 0.45, blue: 0.95).opacity(0.45), radius: 8, x: 0, y: 3)

                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 8) {
                    Text("FLAC2MP3")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("PRO")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.2), Color.purple.opacity(0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                        )
                }

                Text("Transcodificación inteligente de alta fidelidad para macOS")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Header Action Buttons when files are loaded
            if !viewModel.tasks.isEmpty && !viewModel.isProcessing {
                HStack(spacing: 10) {
                    Button {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = true
                        panel.message = "Seleccionar más carpetas FLAC"
                        if panel.runModal() == .OK {
                            viewModel.loadURLs(panel.urls)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Añadir Carpetas")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.allowsMultipleSelection = true
                        panel.message = "Seleccionar más archivos FLAC"
                        if panel.runModal() == .OK {
                            viewModel.loadURLs(panel.urls)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Añadir Archivos")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .padding(.horizontal, 2)
    }

    private var dependencyWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("FFmpeg no encontrado en el sistema")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Para convertir archivos, instala FFmpeg mediante Homebrew en tu Terminal:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("brew install ffmpeg chromaprint", forType: .string)
                copiedCommand = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copiedCommand = false
                }
            } label: {
                Label(copiedCommand ? "¡Copiado!" : "Copiar comando brew", systemImage: copiedCommand ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}
