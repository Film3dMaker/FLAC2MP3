import SwiftUI
import AppKit

public struct SettingsPanel: View {
    @ObservedObject public var settings: AppSettings
    public var outputFolderURL: URL?
    public var sourceFolderURL: URL?
    public var onDestinationChanged: () -> Void

    public init(
        settings: AppSettings,
        outputFolderURL: URL?,
        sourceFolderURL: URL?,
        onDestinationChanged: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.outputFolderURL = outputFolderURL
        self.sourceFolderURL = sourceFolderURL
        self.onDestinationChanged = onDestinationChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Main Controls Strip
            HStack(alignment: .center, spacing: 10) {
                // Audio Quality Pill
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13, weight: .semibold))

                    Text("Calidad:")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)

                    Picker("", selection: $settings.bitrate) {
                        ForEach(Bitrate.allCases) { bitrate in
                            Text(bitrate.rawValue).tag(bitrate)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

                // Destination Mode Pill
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13, weight: .semibold))

                    Text("Destino:")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)

                    Picker("", selection: $settings.destinationMode) {
                        ForEach(OutputDestinationMode.allCases) { dest in
                            Text(dest.rawValue).tag(dest)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

                // CPU Multi-Thread Turbo Pill
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13, weight: .semibold))

                    Text("Hilos:")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)

                    Picker("", selection: $settings.concurrencyThreads) {
                        Text("1 hilo").tag(1)
                        Text("2 hilos").tag(2)
                        Text("4 hilos").tag(4)
                        Text("8 hilos").tag(8)
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

                // Metadata Pill
                HStack(spacing: 6) {
                    Image(systemName: "tag")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13, weight: .semibold))

                    Text("Tags:")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)

                    Picker("", selection: $settings.recognitionMode) {
                        ForEach(RecognitionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

                Spacer()
            }

            // Custom Folder Row (if active)
            if settings.destinationMode == .customFolder {
                HStack(spacing: 10) {
                    Image(systemName: "folder.badge.gearshape.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 15))

                    Text(settings.customOutputFolderPath.isEmpty ? "Haz clic en 'Examinar' para elegir la carpeta central de salida..." : settings.customOutputFolderPath)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(settings.customOutputFolderPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        chooseCustomFolder()
                    } label: {
                        Text("Examinar...")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.05, green: 0.55, blue: 1.0), Color(red: 0.25, green: 0.35, blue: 0.95)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Options Strip (Toggles & Destination Preview)
            HStack(spacing: 16) {
                Toggle("Copiar carátulas y adjuntos (.jpg, .png, .m3u, .log)", isOn: $settings.copyExtraFiles)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13, weight: .medium, design: .rounded))

                Toggle("Subcarpetas recursivas", isOn: $settings.recursive)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13, weight: .medium, design: .rounded))

                Spacer()

                HStack(spacing: 6) {
                    Text("Salida:")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)

                    Text(previewDestinationPath)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let url = outputFolderURL, FileManager.default.fileExists(atPath: url.path) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Image(systemName: "arrow.up.forward.app.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                        .help("Abrir carpeta en Finder")
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.top, 2)


        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onChange(of: settings.destinationMode) { _ in
            onDestinationChanged()
        }
        .onChange(of: settings.customOutputFolderPath) { _ in
            onDestinationChanged()
        }
    }

    private var previewDestinationPath: String {

        switch settings.destinationMode {
        case .subfolderMP3:
            let folderName = settings.outputFolderName.isEmpty ? "MP3" : settings.outputFolderName
            if let source = sourceFolderURL {
                return source.appendingPathComponent(folderName).path
            } else {
                return ".../<Álbum>/\(folderName)"
            }
        case .customFolder:
            if settings.customOutputFolderPath.isEmpty {
                return "Selecciona destino"
            } else {
                let name = sourceFolderURL?.lastPathComponent ?? "<Álbum>"
                return "\(settings.customOutputFolderPath)/\(name)"
            }
        case .sameAsSource:
            return sourceFolderURL?.path ?? "Misma carpeta"
        }
    }

    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Selecciona la carpeta donde guardar los archivos convertidos"
        panel.prompt = "Seleccionar destino"

        if panel.runModal() == .OK, let url = panel.url {
            settings.customOutputFolderPath = url.path
            onDestinationChanged()
        }
    }
}



