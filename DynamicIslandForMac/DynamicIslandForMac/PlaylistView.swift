import AppKit
import SwiftUI

struct PlaylistView: View {
    @ObservedObject var playlist: PlaylistManager
    @ObservedObject var guide: IslandGuide

    @State private var dragStartSize: CGSize?
    @State private var dragStartMouse: CGPoint?
    @State private var moveStartOrigin: CGPoint?

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(playlist.playlistName.isEmpty ? "Плейлист" : playlist.playlistName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .padding(.leading, 28)
                .padding(.trailing, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(playlist.tracks) { track in
                            trackRow(track)
                                .id(track.index)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
                .onAppear {
                    proxy.scrollTo(playlist.currentIndex, anchor: .center)
                }
                .onChange(of: playlist.currentIndex) { _, index in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            card.fill(.ultraThinMaterial)
            card.fill(Color.black.opacity(0.28))
        }
        .overlay {
            card.stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        }
        .clipShape(card)
        .overlay(alignment: .bottomTrailing) {
            resizeHandle
        }
        .overlay(alignment: .top) {
            Color.clear
                .frame(height: 28)
                .contentShape(Rectangle())
                .gesture(moveGesture)
        }
        .overlay(alignment: .topLeading) {
            closeButton
                .zIndex(20)
        }
        .environment(\.colorScheme, .dark)
        .environment(\.islandGuide, guide)
        .reportGuideFrame(.playlistPanel, guide: guide, window: playlistWindow)
    }

    private func trackRow(_ track: PlaylistManager.Track) -> some View {
        let current = track.index == playlist.currentIndex
        return Button {
            playlist.play(track)
        } label: {
            HStack(spacing: 8) {
                Text("\(track.index)")
                    .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white.opacity(current ? 0.7 : 0.28))
                    .frame(width: 28, alignment: .trailing)
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.name)
                        .font(.system(size: 12, weight: current ? .semibold : .medium, design: .rounded))
                        .foregroundColor(.white.opacity(current ? 0.96 : 0.78))
                        .lineLimit(1)
                    if !track.artist.isEmpty {
                        Text(track.artist)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(current ? 0.55 : 0.32))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(current ? 0.12 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { _ in
                let mouse = NSEvent.mouseLocation
                if moveStartOrigin == nil, let window = playlistWindow {
                    playlist.beginMove(origin: window.frame.origin)
                    moveStartOrigin = window.frame.origin
                    dragStartMouse = mouse
                }
                guard let start = moveStartOrigin, let startMouse = dragStartMouse else { return }
                playlist.liveMove(from: start, mouse: mouse, origin: startMouse)
            }
            .onEnded { _ in
                playlist.endMove()
                moveStartOrigin = nil
                dragStartMouse = nil
            }
    }

    private var closeButton: some View {
        Button {
            playlist.isOpen = false
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 0.88, green: 0.30, blue: 0.28).opacity(0.72))
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .frame(width: 14, height: 14)
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.black.opacity(0.48))
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var resizeHandle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 14, height: 14)
            .padding(10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in
                        let mouse = NSEvent.mouseLocation
                        if dragStartSize == nil {
                            dragStartSize = playlist.panelSize
                            dragStartMouse = mouse
                            if let window = playlistWindow {
                                playlist.beginResize(left: window.frame.minX, top: window.frame.maxY)
                            }
                        }
                        guard let startSize = dragStartSize, let startMouse = dragStartMouse else { return }
                        playlist.liveResize(from: startSize, mouse: mouse, origin: startMouse)
                    }
                    .onEnded { _ in
                        playlist.endResize()
                        dragStartSize = nil
                        dragStartMouse = nil
                    }
            )
    }

    private var playlistWindow: NSWindow? {
        NSApp.windows.first { $0.contentView is PlaylistHost }
    }
}

protocol PlaylistHost {}

final class PlaylistHostingView<Content: View>: NSHostingView<Content>, PlaylistHost {
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? super.hitTest(point) : nil
    }
}
