import SwiftUI
import AppKit

public struct ProgressSection: View {
    @ObservedObject public var viewModel: MainViewModel

    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Live Progress Bar (when converting)
            if viewModel.isProcessing {
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.05, green: 0.52, blue: 1.0), Color(red: 0.35, green: 0.25, blue: 0.95)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(viewModel.overallProgress))), height: 8)
                                .animation(.easeInOut(duration: 0.25), value: viewModel.overallProgress)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)

                            Text(viewModel.statusMessage)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("\(Int(viewModel.overallProgress * 100))%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                    }
                }
            }

            // Main Action Row
            HStack(alignment: .center, spacing: 14) {
                // Left Status / Summary Pills
                if !viewModel.tasks.isEmpty && !viewModel.isProcessing {
                    HStack(spacing: 8) {
                        if viewModel.completedCount > 0 && viewModel.completedCount == viewModel.totalCount {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 15))

                                Text("¡Conversión completada!")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            if let outURL = viewModel.resolvedOutputFolderURL, FileManager.default.fileExists(atPath: outURL.path) {
                                Button {
                                    NSWorkspace.shared.open(outURL)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 13))
                                        Text("Abrir Carpeta")
                                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        } else if viewModel.failCount > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 15))

                                Text("\(viewModel.failCount) archivo(s) con error")
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 14))

                                Text("\(viewModel.tasks.count) pistas listas para convertir")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                // Right Action Buttons
                if viewModel.isProcessing {
                    Button {
                        viewModel.cancelConversion()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Cancelar")
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                } else if !viewModel.tasks.isEmpty {
                    if viewModel.failCount > 0 {
                        Button {
                            viewModel.retryFailed()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Reintentar Fallidos (\(viewModel.failCount))")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(Color(NSColor.controlBackgroundColor))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Main Action Button
                    Button {
                        Task {
                            await viewModel.startConversion()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: viewModel.completedCount > 0 && viewModel.completedCount == viewModel.totalCount ? "arrow.clockwise" : "bolt.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(viewModel.completedCount > 0 && viewModel.completedCount == viewModel.totalCount ? "Volver a Convertir" : "Iniciar Transcodificación")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
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
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.15)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color(red: 0.05, green: 0.45, blue: 0.95).opacity(0.45), radius: 14, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isFFmpegMissing)
                }
            }

        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)



    }
}
