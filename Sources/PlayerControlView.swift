import SwiftUI

struct PlayerControlView: View {
    let viewModel: PlayerViewModel

    var body: some View {
        HStack(spacing: 10) {
            controlButton(symbol: "gobackward.10", tint: .secondary) {
                viewModel.seek(by: -viewModel.largeSeekSeconds)
            }

            controlButton(label: "−1", tint: .secondary) {
                viewModel.seek(by: -viewModel.smallSeekSeconds)
            }

            controlButton(
                symbol: viewModel.isPlaying ? "pause.fill" : "play.fill",
                tint: viewModel.isPlaying ? .red : .green,
                filled: true
            ) {
                viewModel.playPause()
            }
            .frame(width: 60, height: 44)

            controlButton(label: "+1", tint: .secondary) {
                viewModel.seek(by: viewModel.smallSeekSeconds)
            }

            controlButton(symbol: "goforward.10", tint: .secondary) {
                viewModel.seek(by: viewModel.largeSeekSeconds)
            }
        }
    }

    private func controlButton(
        symbol: String,
        tint: Color,
        filled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(filled ? tint : tint.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(filled ? .white : tint)
                }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func controlButton(
        label: String,
        tint: Color,
        filled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(filled ? tint : tint.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(filled ? .white : tint)
                }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
