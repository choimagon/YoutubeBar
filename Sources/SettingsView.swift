import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: PlayerViewModel

    var body: some View {
        Form {
            Section("Playback") {
                Stepper(value: $viewModel.smallSeekSeconds, in: 1...15, step: 1) {
                    Text("Small seek: \(Int(viewModel.smallSeekSeconds)) sec")
                }

                Stepper(value: $viewModel.largeSeekSeconds, in: 10...60, step: 5) {
                    Text("Large seek: \(Int(viewModel.largeSeekSeconds)) sec")
                }
            }

            Section("Current Video") {
                Text(viewModel.currentTitle)
                Text("https://www.youtube.com/watch?v=\(viewModel.currentVideoID)")
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
