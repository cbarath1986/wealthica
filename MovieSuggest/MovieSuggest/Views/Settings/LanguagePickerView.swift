import SwiftUI

struct LanguagePickerView: View {
    @Binding var selection: Set<String>
    @State private var searchText = ""

    private var filtered: [Language] {
        guard !searchText.isEmpty else { return Language.all }
        return Language.all.filter {
            $0.englishName.localizedCaseInsensitiveContains(searchText)
                || $0.nativeName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filtered) { language in
            Button {
                toggle(language.code)
            } label: {
                HStack {
                    Text(language.displayName).foregroundStyle(.primary)
                    Spacer()
                    if selection.contains(language.code) {
                        Image(systemName: "checkmark").foregroundStyle(.tint)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search languages")
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ code: String) {
        if selection.contains(code) {
            guard selection.count > 1 else { return }
            selection.remove(code)
        } else {
            selection.insert(code)
        }
    }
}
