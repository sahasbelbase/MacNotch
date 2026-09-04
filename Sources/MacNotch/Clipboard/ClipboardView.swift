import SwiftUI

/// Complete clipboard experience with categories, search, keyboard navigation, and inspection.
public struct ClipboardView: View {
    @ObservedObject var clipboardManager: ClipboardManager

    @FocusState private var isSearchFocused: Bool
    @State private var selectedIndex: Int = 0
    @State private var inspectedItem: ClipboardItem?

    public init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
    }

    private var items: [ClipboardItem] {
        clipboardManager.filteredItems
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 8) {
                // Top controls: Category bar + Search bar
                HStack(spacing: 8) {
                    ClipboardCategoryBar(selectedCategory: $clipboardManager.selectedCategory) { _ in
                        selectedIndex = 0
                    }

                    Spacer()

                    ClipboardSearchBar(text: $clipboardManager.searchQuery, isFocused: $isSearchFocused)
                        .frame(width: 170)
                }
                .padding(.horizontal, 4)

                // Carousel / Results Area
                if items.isEmpty {
                    emptyStateView
                } else {
                    carouselView
                }
            }
            .frame(maxWidth: .infinity)

            // Detail Inspector Overlay
            if let item = inspectedItem {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            inspectedItem = nil
                        }
                    }

                ClipboardDetailView(
                    item: item,
                    onCopy: {
                        clipboardManager.copyToPasteboard(item)
                    },
                    onCopyPlainText: {
                        clipboardManager.copyPlainTextToPasteboard(item)
                    },
                    onTogglePin: {
                        clipboardManager.togglePin(item: item)
                    },
                    onDelete: {
                        withAnimation {
                            clipboardManager.remove(item: item)
                        }
                    },
                    onClose: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            inspectedItem = nil
                        }
                    }
                )
                .frame(maxWidth: 520, maxHeight: 210)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .zIndex(10)
            }
        }
        // Keyboard event handling
        .onKeyPress(.leftArrow) {
            handleArrowNavigation(delta: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            handleArrowNavigation(delta: 1)
            return .handled
        }
        .onKeyPress(.return) {
            if inspectedItem == nil && !items.isEmpty && selectedIndex < items.count {
                clipboardManager.copyToPasteboard(items[selectedIndex])
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.space) {
            if inspectedItem == nil && !items.isEmpty && selectedIndex < items.count {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    inspectedItem = items[selectedIndex]
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if inspectedItem != nil {
                withAnimation { inspectedItem = nil }
                return .handled
            } else if !clipboardManager.searchQuery.isEmpty {
                clipboardManager.searchQuery = ""
                return .handled
            }
            return .ignored
        }
    }

    private var carouselView: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 4) {
                // Previous Button
                Button(action: {
                    handleArrowNavigation(delta: -1)
                    if selectedIndex < items.count {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(items[selectedIndex].id, anchor: .center)
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .frame(width: 14, height: 40)
                }
                .buttonStyle(.plain)

                // Cards Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            ClipboardCardView(
                                item: item,
                                isSelected: index == selectedIndex,
                                onCopy: {
                                    clipboardManager.copyToPasteboard(item)
                                },
                                onCopyPlainText: {
                                    clipboardManager.copyPlainTextToPasteboard(item)
                                },
                                onTogglePin: {
                                    withAnimation {
                                        clipboardManager.togglePin(item: item)
                                    }
                                },
                                onDelete: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        clipboardManager.remove(item: item)
                                    }
                                },
                                onInspect: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        inspectedItem = item
                                    }
                                }
                            )
                            .id(item.id)
                            .onTapGesture {
                                selectedIndex = index
                                clipboardManager.copyToPasteboard(item)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Next Button
                Button(action: {
                    handleArrowNavigation(delta: 1)
                    if selectedIndex < items.count {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(items[selectedIndex].id, anchor: .center)
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .frame(width: 14, height: 40)
                }
                .buttonStyle(.plain)
            }
            .onChange(of: selectedIndex) { newIndex in
                if newIndex < items.count {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(items[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: clipboardManager.searchQuery.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 22))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text(clipboardManager.searchQuery.isEmpty ? "No items in this category" : "No matches for \"\(clipboardManager.searchQuery)\"")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            if !clipboardManager.searchQuery.isEmpty {
                Button("Clear Search") {
                    clipboardManager.searchQuery = ""
                }
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: DesignSystem.Dimensions.cardHeight)
    }

    private func handleArrowNavigation(delta: Int) {
        guard !items.isEmpty else { return }
        let nextIndex = selectedIndex + delta
        if nextIndex >= 0 && nextIndex < items.count {
            selectedIndex = nextIndex
        }
    }
}
