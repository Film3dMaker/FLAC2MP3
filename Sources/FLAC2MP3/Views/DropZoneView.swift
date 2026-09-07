import SwiftUI
import UniformTypeIdentifiers
import AppKit

public struct DropZoneView: View {
    @ObservedObject public var viewModel: MainViewModel
    @State private var isDragging = false

    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Main Frosted Glass Stage
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: isDragging
                                    ? [Color(red: 0.1, green: 0.6, blue: 1.0), Color(red: 0.8, green: 0.2, blue: 0.9)]
                                    : [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isDragging ? 2 : 1
                        )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8)

            VStack(spacing: 24) {
                // CleanMyMac Iconic Multi-Layered Glowing Glass Orb
                ZStack {
                    // Outer Soft Ambient Aura
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.1, green: 0.55, blue: 1.0).opacity(isDragging ? 0.4 : 0.22),
                                    Color(red: 0.8, green: 0.2, blue: 0.6).opacity(isDragging ? 0.25 : 0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 85
                            )
                        )
                        .frame(width: 170, height: 170)
                        .blur(radius: 12)

                    // Outer Specular Glass Ring
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 126, height: 126)

                    // Middle Frosted Glass Disc
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color(red: 0.1, green: 0.45, blue: 0.95).opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(
                            color: Color(red: 0.05, green: 0.45, blue: 0.95).opacity(isDragging ? 0.5 : 0.3),
                            radius: 20,
                            x: 0,
                            y: 8
                        )

                    // Inner Core & Waveform Icon
                    Image(systemName: isDragging ? "arrow.down.circle.fill" : "waveform.circle.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color(red: 0.7, green: 0.9, blue: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.6), radius: 10, x: 0, y: 4)
                        .scaleEffect(isDragging ? 1.15 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isDragging)
                }

                // Clean Typography & Subtitle
                VStack(spacing: 8) {
                    Text("Transcodificación Inteligente")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Arrastra carpetas o archivos FLAC para convertir a MP3 320 kbps con carátulas y tags")
                        .font(.system(size: 14.5, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480)
                }

                // Tactile Glass Buttons
                HStack(spacing: 14) {
                    Button {
                        selectFolder()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill.badge.plus")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Seleccionar Carpetas...")
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.55, blue: 1.0),
                                    Color(red: 0.05, green: 0.35, blue: 0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color(red: 0.05, green: 0.45, blue: 0.95).opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectFiles()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Seleccionar Archivos...")
                                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .foregroundColor(.primary)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)

                // Specs Footnote
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12.5))
                    Text("Conversión audiófila LAME • ID3v2.3 Automático • Aceleración Multi-Core")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.85))
                }
                .padding(.top, 6)

            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .onDrop(of: [.fileURL, .folder, .item], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {


        var droppedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let url = item as? URL {
                        droppedURLs.append(url)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        droppedURLs.append(url)
                    } else if let str = item as? String, let url = URL(string: str) {
                        droppedURLs.append(url)
                    }
                }
            } else {
                provider.loadItem(forTypeIdentifier: "public.folder", options: nil) { item, _ in
                    defer { group.leave() }
                    if let url = item as? URL {
                        droppedURLs.append(url)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        droppedURLs.append(url)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if !droppedURLs.isEmpty {
                viewModel.loadURLs(droppedURLs)
            }
        }

        return true
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Selecciona una o más carpetas con archivos FLAC"
        panel.prompt = "Cargar carpeta"

        if panel.runModal() == .OK {
            viewModel.loadURLs(panel.urls)
        }
    }

    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "flac") ?? .audio,
            .audio
        ]
        panel.message = "Selecciona archivos FLAC para convertir"
        panel.prompt = "Cargar archivos"

        if panel.runModal() == .OK {
            viewModel.loadURLs(panel.urls)
        }
    }
}


