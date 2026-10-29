import AppKit
import SwiftUI

/// The shelf: a Drop Bar that holds files, and a grid of action targets.
/// Name of the coordinate space drop-target frames are measured in.
enum ShelfLayout {
    static let coordinateSpace = "raf.shelf"
}

@MainActor
struct ShelfView: View {
    @EnvironmentObject private var store: ShelfStore
    @EnvironmentObject private var settings: AppSettings

    private let columns = Array(repeating: GridItem(.fixed(84), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            DropBar()
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(settings.folders) { folder in
                    ActionTile(
                        id: .folder(folder.id),
                        title: folder.name,
                        subtitle: folder.mode == .move ? "Move" : "Copy",
                        systemImage: "folder.fill",
                        tint: .blue
                    )
                }
                ActionTile(id: .airDrop, title: "AirDrop", subtitle: nil, systemImage: "dot.radiowaves.left.and.right", tint: .cyan)
                ActionTile(id: .shorten, title: "Shorten URL", subtitle: nil, systemImage: "link", tint: .purple)
                ActionTile(id: .addFolder, title: "Add Folder", subtitle: nil, systemImage: "plus", tint: .gray)
            }
            if let status = store.status {
                StatusBanner(status: status)
            }
        }
        .padding(12)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .coordinateSpace(name: ShelfLayout.coordinateSpace)
        .onPreferenceChange(TargetFramesKey.self) { frames in
            Task { @MainActor in ShelfStore.shared.targetFrames = frames }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Raf")
                .font(.headline)
            if store.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            if store.items.count > 1 {
                DragAllHandle(urls: store.items.map(\.url))
            }
            if !store.items.isEmpty {
                Button("Clear") { store.clear() }
                    .buttonStyle(.borderless)
            }
            HeaderButton(
                systemImage: store.isPinned ? "pin.fill" : "pin",
                help: store.isPinned ? "Unpin: close when I click elsewhere" : "Pin: keep the shelf open"
            ) {
                store.isPinned.toggle()
            }
            HeaderButton(systemImage: "gearshape", help: "Settings") {
                ShelfController.shared.hide()
                SettingsWindowController.shared.show()
            }
        }
    }
}

// MARK: Drop Bar

/// Holds files and links until they are dragged out, like Dropzone's Drop Bar.
@MainActor
private struct DropBar: View {
    @EnvironmentObject private var store: ShelfStore

    var body: some View {
        let isTargeted = store.hoveredTarget == .shelf

        Group {
            if store.items.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.title2)
                    Text("Drop Bar")
                        .font(.callout.weight(.medium))
                    Text("Drop files here to hold them, drag them out when you're ready")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 84)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.items) { item in
                            DropBarRow(item: item)
                        }
                    }
                    .padding(4)
                }
                .frame(height: min(CGFloat(store.items.count) * 30 + 8, 158))
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
        .dropTarget(.shelf)
    }
}

@MainActor
private struct DropBarRow: View {
    @EnvironmentObject private var store: ShelfStore
    let item: ShelfItem

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 8) {
                icon
                    .frame(width: 22, height: 22)
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.callout)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .overlay(DragSource(urls: [item.url]))
            .help("Drag out to use it. Double-click to open. Right-click for more.")

            Button {
                store.remove(urls: [item.url])
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .help("Remove from Drop Bar")
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
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

/// Drags every Drop Bar item out at once.
private struct DragAllHandle: View {
    let urls: [URL]

    var body: some View {
        Image(systemName: "square.stack.3d.up.fill")
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .overlay(DragSource(urls: urls))
            .help("Drag all \(urls.count) items")
    }
}

// MARK: Action grid

@MainActor
private struct ActionTile: View {
    @EnvironmentObject private var store: ShelfStore

    let id: DropTargetID
    let title: String
    let subtitle: String?
    let systemImage: String
    let tint: Color

    var body: some View {
        let isTargeted = store.hoveredTarget == id

        Button {
            store.performOnShelf(id)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .frame(width: 84, height: 88)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isTargeted ? tint.opacity(0.28) : Color.clear)
            )
            .scaleEffect(isTargeted ? 1.06 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isTargeted)
        .dropTarget(id)
    }
}

private struct HeaderButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(help)
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

// MARK: Drop target frames

/// Collects each drop target's frame so ShelfDropView can hit-test drags.
struct TargetFramesKey: PreferenceKey {
    static let defaultValue: [DropTargetID: CGRect] = [:]

    static func reduce(value: inout [DropTargetID: CGRect], nextValue: () -> [DropTargetID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func dropTarget(_ id: DropTargetID) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TargetFramesKey.self,
                    value: [id: proxy.frame(in: .named(ShelfLayout.coordinateSpace))]
                )
            }
        )
    }
}
