import AppKit
import SwiftUI

@MainActor
struct ShelfView: View {
    @EnvironmentObject private var store: ShelfStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ShelfArea()
            Divider()
            actions
            if let status = store.status {
                StatusBanner(status: status)
                    .transition(.opacity)
            }
        }
        .padding(12)
        .frame(width: 280, height: 440, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .animation(.easeInOut(duration: 0.15), value: store.status)
    }

    private var header: some View {
        HStack {
            Text("Raf")
                .font(.headline)
            if store.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            if !store.items.isEmpty {
                Button("Clear") { store.clear() }
                    .buttonStyle(.borderless)
            }
            Button {
                ShelfController.shared.hide()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Hide shelf")
        }
    }

    private var actions: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(settings.folders) { folder in
                    DropTargetRow(
                        title: folder.name,
                        subtitle: folder.mode == .move ? "Move here" : "Copy here",
                        systemImage: "folder.fill",
                        onDrop: { store.handleDrop($0, action: .folder(folder)) },
                        onTap: { store.performOnShelf(.folder(folder)) }
                    )
                }

                if settings.folders.isEmpty {
                    Text("Add folders in Settings to drop files into them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }

                DropTargetRow(
                    title: "AirDrop",
                    subtitle: "Send to a nearby device",
                    systemImage: "dot.radiowaves.left.and.right",
                    onDrop: { store.handleDrop($0, action: .airDrop) },
                    onTap: { store.performOnShelf(.airDrop) }
                )

                DropTargetRow(
                    title: "Shorten URL",
                    subtitle: "Drop a link, or click to shorten the clipboard",
                    systemImage: "link",
                    onDrop: { store.handleDrop($0, action: .shorten) },
                    onTap: { store.performOnShelf(.shorten) }
                )
            }
        }
    }
}

/// The holding area: files dropped here stay until dragged out or removed.
@MainActor
private struct ShelfArea: View {
    @EnvironmentObject private var store: ShelfStore
    @State private var isTargeted = false

    var body: some View {
        Group {
            if store.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.title2)
                    Text("Drop files here to hold them")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(store.items) { item in
                            ShelfItemRow(item: item)
                        }
                    }
                    .padding(4)
                }
                .frame(height: 130)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .onDrop(of: DroppedContent.types, isTargeted: $isTargeted) { providers in
            store.handleDrop(providers, action: .shelf)
        }
    }
}

@MainActor
private struct ShelfItemRow: View {
    @EnvironmentObject private var store: ShelfStore
    let item: ShelfItem

    var body: some View {
        HStack(spacing: 8) {
            icon
                .frame(width: 22, height: 22)
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.callout)
            Spacer(minLength: 4)
            Button {
                store.remove(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .help("Remove from shelf")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onDrag {
            if item.url.isFileURL, let provider = NSItemProvider(contentsOf: item.url) {
                return provider
            }
            return NSItemProvider(object: item.url as NSURL)
        }
    }

    private var title: String {
        item.url.isFileURL ? item.url.lastPathComponent : item.url.absoluteString
    }

    @ViewBuilder
    private var icon: some View {
        if item.url.isFileURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
        } else {
            Image(systemName: "link")
        }
    }
}

private struct DropTargetRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let onDrop: ([NSItemProvider]) -> Bool
    let onTap: () -> Void

    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 26)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.05))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onDrop(of: DroppedContent.types, isTargeted: $isTargeted, perform: onDrop)
    }
}

private struct StatusBanner: View {
    let status: StatusMessage

    var body: some View {
        Label(status.text, systemImage: status.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.caption)
            .foregroundStyle(status.isError ? Color.orange : Color.green)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
