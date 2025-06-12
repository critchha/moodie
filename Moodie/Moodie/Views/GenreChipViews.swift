import SwiftUI

struct GenreChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PickerOption: Identifiable {
    let label: String
    let value: String
    var id: String { value }
}

struct GenreChipList: View {
    let options: [PickerOption]
    @Binding var selectedGenres: Set<String>
    var body: some View {
        LazyHStack(spacing: 12) {
            ForEach(options) { option in
                GenreChip(
                    label: option.label,
                    isSelected: selectedGenres.contains(option.value)
                ) {
                    if selectedGenres.contains(option.value) {
                        selectedGenres.remove(option.value)
                    } else {
                        selectedGenres.insert(option.value)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct GenreChipRow: View {
    let options: [PickerOption]
    @Binding var selectedGenres: Set<String>
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GenreChipList(options: options, selectedGenres: $selectedGenres)
        }
    }
} 