import SwiftUI

struct CaptureHistoryView: View {
    @StateObject private var history = CaptureHistory.shared

    var body: some View {
        VStack(spacing: 0) {
            if history.entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 4) {
                        Text("No captures yet")
                            .font(.headline)
                        Text("Use ⌘⌥M or the menu bar to capture a formula")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        CaptureManager.shared.startCapture()
                    } label: {
                        Label("Capture Formula", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(history.entries) { entry in
                        CaptureRow(entry: entry) {
                            history.delete($0)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Label("Recent Captures", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    history.clearAll()
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(history.entries.isEmpty)
                .help("Delete all captures")
            }
        }
        .frame(minWidth: 520, minHeight: 380)
    }
}

private struct CaptureRow: View {
    let entry: CaptureEntry
    let onDelete: (CaptureEntry) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Thumbnail
            Group {
                if let url = entry.imageURL, let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 92, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.quaternaryLabelColor).opacity(0.3))
                        .frame(width: 92, height: 68)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title3)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // Timestamp
                    Label {
                        Text(entry.timestamp, style: .date)
                            .font(.caption)
                    } icon: {
                        Image(systemName: "calendar")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .labelStyle(.titleAndIcon)

                    // Provider + Model
                    HStack(spacing: 4) {
                        Image(systemName: providerIcon(for: entry.provider))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(entry.provider)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(entry.model)
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.85))
                            .lineLimit(1)
                    }
                }

                // Formula content
                Text(entry.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(4)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 8)

            // Actions
            VStack(alignment: .trailing, spacing: 6) {
                // Format badge
                Text(entry.formatLabel)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
                    .foregroundColor(.accentColor)

                HStack(spacing: 4) {
                    // Copy button
                    Button {
                        ClipboardManager.copyText(entry.content)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .help("Copy \(entry.formatLabel)")

                    // Delete button
                    Button(role: .destructive) {
                        onDelete(entry)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .help("Delete capture")
                    .opacity(isHovering ? 1 : 0.6)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button {
                ClipboardManager.copyText(entry.content)
            } label: {
                Label("Copy \(entry.formatLabel)", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                onDelete(entry)
            } label: {
                Label("Delete Capture", systemImage: "trash")
            }
        }
    }

    private func providerIcon(for provider: String) -> String {
        if provider.lowercased().contains("apfel") { return "apple.logo" }
        if provider.lowercased().contains("google") { return "globe" }
        if provider.lowercased().contains("openai") { return "brain" }
        if provider.lowercased().contains("anthropic") { return "a.circle" }
        if provider.lowercased().contains("github") { return "chevron.left.forwardslash.chevron.right" }
        return "cpu"
    }
}
