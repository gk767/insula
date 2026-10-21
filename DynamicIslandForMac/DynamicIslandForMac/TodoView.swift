import AppKit
import SwiftUI

struct TodoView: View {
    @ObservedObject var todo: TodoManager

    @State private var draft = ""
    @State private var hoveredID: UUID?
    @State private var dragStartSize: CGSize?
    @State private var dragStartMouse: CGPoint?
    @State private var moveStartOrigin: CGPoint?
    @FocusState private var inputFocused: Bool

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var accent: Color {
        Color(red: 0.30, green: 0.82, blue: 0.45)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            addRow
            list
            footer
        }
        .padding(.top, 12)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
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
        .onExitCommand {
            todo.isOpen = false
        }
        .onChange(of: todo.isOpen) { _, open in
            guard open else { return }
            focusInput()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            Text("Список дел")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            Spacer(minLength: 0)
            if todo.pendingCount > 0 {
                Text("\(todo.pendingCount)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundColor(.white.opacity(0.38))
            }
        }
        .padding(.leading, 28)
        .padding(.trailing, 12)
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("Новое дело", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .focused($inputFocused)
                .onSubmit(addDraft)

            Button {
                addDraft()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(trimmedDraft.isEmpty ? .white.opacity(0.18) : .white.opacity(0.85))
                    .frame(width: 20, height: 20)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(trimmedDraft.isEmpty)
            .help("Добавить дело")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6)
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if todo.items.isEmpty {
                        emptyState
                    } else {
                        ForEach(todo.items) { item in
                            row(item)
                                .id(item.id)
                        }
                    }
                }
                .padding(.vertical, 2)
                .animation(.easeOut(duration: 0.25), value: todo.items)
            }
            .onChange(of: todo.items.count) { old, new in
                guard new > old, let last = todo.items.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.white.opacity(0.16))
            Text("Пока пусто")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
            Text("Добавьте первое дело выше")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func row(_ item: TodoItem) -> some View {
        let selected = todo.selectedIDs.contains(item.id)
        let completing = todo.completingIDs.contains(item.id)
        let hovered = hoveredID == item.id

        return HStack(spacing: 9) {
            Button {
                guard !completing else { return }
                todo.toggleSelection(item.id)
            } label: {
                selectionCircle(selected: selected, completing: completing)
            }
            .buttonStyle(.plain)
            .disabled(completing)
            .help(selected ? "Снять отметку" : "Отметить для выполнения")

            Text(item.title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(completing ? 0 : 0.9))
                .strikethrough(completing, color: accent.opacity(0.85))
                .lineLimit(2)
                .animation(.easeOut(duration: 0.32), value: completing)

            Spacer(minLength: 0)

            if hovered, !completing {
                Button {
                    todo.delete(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                        .frame(width: 18, height: 18)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Удалить")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(hovered && !completing ? 0.05 : 0))
        )
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                hoveredID = item.id
            } else if hoveredID == item.id {
                hoveredID = nil
            }
        }
        .animation(.easeOut(duration: 0.18), value: completing)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func selectionCircle(selected: Bool, completing: Bool) -> some View {
        ZStack {
            if completing {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accent)
            } else if selected {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 16, height: 16)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.black.opacity(0.72))
            } else {
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.2)
                    .frame(width: 16, height: 16)
            }
        }
        .frame(width: 18, height: 18)
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.18), value: selected)
    }

    private var footer: some View {
        Button {
            todo.markSelectedCompleted()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Отметить как выполненные")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
                if todo.hasSelection {
                    Text("\(todo.selectedCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded).monospacedDigit())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule(style: .continuous).fill(accent.opacity(0.28)))
                }
            }
            .foregroundColor(todo.hasSelection ? .white.opacity(0.95) : .white.opacity(0.3))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(todo.hasSelection ? accent.opacity(0.24) : Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        todo.hasSelection ? accent.opacity(0.55) : Color.white.opacity(0.08),
                        lineWidth: 0.8
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!todo.hasSelection)
        .help(todo.hasSelection ? "Отметить выбранные дела выполненными" : "Сначала отметьте хотя бы одно дело")
        .animation(.easeInOut(duration: 0.2), value: todo.hasSelection)
    }

    private func addDraft() {
        guard todo.add(draft) != nil else { return }
        draft = ""
        inputFocused = true
    }

    private func focusInput() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            inputFocused = true
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { _ in
                let mouse = NSEvent.mouseLocation
                if moveStartOrigin == nil, let window = todoWindow {
                    todo.beginMove(origin: window.frame.origin)
                    moveStartOrigin = window.frame.origin
                    dragStartMouse = mouse
                }
                guard let start = moveStartOrigin, let startMouse = dragStartMouse else { return }
                todo.liveMove(from: start, mouse: mouse, origin: startMouse)
            }
            .onEnded { _ in
                todo.endMove()
                moveStartOrigin = nil
                dragStartMouse = nil
            }
    }

    private var closeButton: some View {
        Button {
            todo.isOpen = false
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
        .help("Закрыть")
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
                            dragStartSize = todo.panelSize
                            dragStartMouse = mouse
                            if let window = todoWindow {
                                todo.beginResize(left: window.frame.minX, top: window.frame.maxY)
                            }
                        }
                        guard let startSize = dragStartSize, let startMouse = dragStartMouse else { return }
                        todo.liveResize(from: startSize, mouse: mouse, origin: startMouse)
                    }
                    .onEnded { _ in
                        todo.endResize()
                        dragStartSize = nil
                        dragStartMouse = nil
                    }
            )
    }

    private var todoWindow: NSWindow? {
        NSApp.windows.first { $0.contentView is TodoHost }
    }
}

protocol TodoHost {}

final class TodoHostingView<Content: View>: NSHostingView<Content>, TodoHost {
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? super.hitTest(point) : nil
    }
}
