import SwiftUI

struct CaptureHistoryView: View {
    @StateObject private var history = CaptureHistory.shared

    var body: some View {
        VStack(spacing: 0) {
            if history.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No captures yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(history.entries) { entry in
                        CaptureRow(entry: entry)
                    }
                }
                .listStyle(.plain)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear All") {
                    history.clearAll()
                }
                .disabled(history.entries.isEmpty)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}

private struct CaptureRow: View {
    let entry: CaptureEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let url = entry.imageURL, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(width: 80, height: 60)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(entry.provider) · \(entry.model)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(entry.content)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(3)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(entry.formatLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Button {
                    ClipboardManager.copyText(entry.content)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy \(entry.formatLabel)")
            }
        }
        .padding(.vertical, 4)
    }
}
