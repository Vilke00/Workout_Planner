import SwiftUI

/// Bottom sheet with minute / second wheels.
struct RestPickerSheet: View {
    @Binding var seconds: Int
    var title: String = "Rest Timer"
    var allowsOff: Bool = true

    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 0
    @State private var secs = 0

    var body: some View {
        NavigationStack {
            RestWheels(minutes: $minutes, seconds: $secs)
                .padding(.horizontal)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if allowsOff {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Off") {
                                seconds = 0
                                dismiss()
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            seconds = minutes * 60 + secs
                            dismiss()
                        }
                        .bold()
                    }
                }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .onAppear {
            minutes = min(seconds / 60, 30)
            secs = (seconds % 60) / 5 * 5
        }
    }
}

/// Two wheel pickers side by side: minutes 0–30, seconds 0–55 (step 5).
struct RestWheels: View {
    @Binding var minutes: Int
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: 0) {
            Picker("Minutes", selection: $minutes) {
                ForEach(0...30, id: \.self) { value in
                    Text("\(value) min").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            .contentShape(Rectangle())

            Picker("Seconds", selection: $seconds) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { value in
                    Text("\(value) s").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            .contentShape(Rectangle())
        }
    }
}
