import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            videoSection
            metadataSection
            PlayerControlView(viewModel: viewModel)
            volumeSection
            searchSection
            urlSection
            footer
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .padding(.top, 8)
        .frame(width: 520)
        .background(backgroundColor)
        .sheet(isPresented: $viewModel.isSearchPresented) {
            YouTubeSearchSheetView(viewModel: viewModel)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("YoutubeBar")
                .font(.system(size: 20, weight: .semibold))
        }
    }

    private var videoSection: some View {
        YouTubeWebView(viewModel: viewModel)
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.12), lineWidth: 1)
            }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.currentTitle)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)

            HStack {
                Text("\(PlayerViewModel.formattedTime(viewModel.currentTime)) / \(PlayerViewModel.formattedTime(viewModel.duration))")
                Spacer()
                Text(viewModel.isPlaying ? "Playing" : "Paused")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            if !viewModel.playerErrorMessage.isEmpty {
                Text(viewModel.playerErrorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }
        }
    }

    private var volumeSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)

                Text("Volume")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64, alignment: .leading)

            Slider(
                value: Binding(
                    get: { viewModel.volumeLevel },
                    set: { viewModel.setVolume($0) }
                ),
                in: 0...100
            )
            .tint(.red)
        }
    }

    private var urlSection: some View {
        HStack(spacing: 8) {
            Button("Load") {
                viewModel.loadFromInput()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            TextField("https://www.youtube.com/watch?v=...", text: $viewModel.urlText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.loadFromInput()
                }
        }
    }

    private var searchSection: some View {
        Button("Search") {
            viewModel.presentSearch()
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }

    private var footer: some View {
        HStack {
            Text("made by choi")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Open in Browser") {
                viewModel.openInBrowser()
            }
            .buttonStyle(.link)

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.link)
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(red: 0.96, green: 0.96, blue: 0.97)
    }
}
