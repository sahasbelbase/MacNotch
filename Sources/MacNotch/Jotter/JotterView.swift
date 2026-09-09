import SwiftUI

/// Notch Jotter view with an instant scratchpad and interactive checklist.
public struct JotterView: View {
    @ObservedObject var jotterManager: JotterManager
    @State private var newTaskTitle: String = ""
    @State private var copiedFeedback: Bool = false

    public init(jotterManager: JotterManager) {
        self.jotterManager = jotterManager
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Left Column: Quick Notes Scratchpad
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Scratchpad", systemImage: "note.text")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.yellow)

                    Spacer()

                    if !jotterManager.noteText.isEmpty {
                        Button("Clear") {
                            withAnimation { jotterManager.clearAllNotes() }
                        }
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .buttonStyle(.plain)
                    }
                }

                TextEditor(text: $jotterManager.noteText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignSystem.Colors.subtleBorder, lineWidth: 1)
                            )
                    )
            }
            .frame(maxWidth: .infinity)

            Divider()
                .background(DesignSystem.Colors.subtleBorder)

            // Right Column: Interactive Checklist
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Quick Checklist", systemImage: "checklist")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.mint)

                    Spacer()

                    Button(action: {
                        jotterManager.copyAllToClipboard()
                        withAnimation { copiedFeedback = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { copiedFeedback = false }
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                            Text(copiedFeedback ? "Copied!" : "Copy All")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(copiedFeedback ? .green : DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy notes and checklist to clipboard")
                }

                // Add task input
                HStack(spacing: 6) {
                    TextField("Add task... (Press ↩)", text: $newTaskTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .onSubmit {
                            guard !newTaskTitle.isEmpty else { return }
                            withAnimation(DesignSystem.Animation.collapseSpring) {
                                jotterManager.addTask(newTaskTitle)
                                newTaskTitle = ""
                            }
                        }

                    Button(action: {
                        guard !newTaskTitle.isEmpty else { return }
                        withAnimation(DesignSystem.Animation.collapseSpring) {
                            jotterManager.addTask(newTaskTitle)
                            newTaskTitle = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.mint)
                    }
                    .buttonStyle(.plain)
                }

                // Tasks list
                if jotterManager.tasks.isEmpty {
                    VStack(spacing: 4) {
                        Spacer()
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No pending tasks")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(jotterManager.tasks) { task in
                                taskRow(task)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(8)
    }

    private func taskRow(_ task: JotterTask) -> some View {
        HStack(spacing: 6) {
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    jotterManager.toggleTask(id: task.id)
                }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12))
                    .foregroundColor(task.isCompleted ? .mint : .white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 11))
                .foregroundColor(task.isCompleted ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                .strikethrough(task.isCompleted, color: DesignSystem.Colors.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                withAnimation {
                    jotterManager.deleteTask(id: task.id)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }
}
