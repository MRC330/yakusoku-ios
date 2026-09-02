import SwiftUI

struct RootView: View {
    @StateObject private var model = WebViewModel()

    var body: some View {
        ZStack {
            WebViewContainer(model: model)
                .ignoresSafeArea(edges: .bottom)

            if model.isLoading {
                LoadingOverlay(progress: model.progress)
            }

            if let msg = model.notice {
                VStack {
                    Spacer()
                    NoticeBanner(text: msg) { model.reload() }
                        .padding(.bottom, 8)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: model.isLoading)
        .animation(.easeInOut(duration: 0.22), value: model.notice)
        .onAppear { model.loadIfNeeded() }
    }
}

// MARK: - 首屏加载遮罩

private struct LoadingOverlay: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView(value: max(progress, 0.05)) 
                    .progressViewStyle(.linear)
                    .tint(Color(red: 1.0, green: 0.42, blue: 0.24))
                    .frame(width: 160)

                Text("yakusoku")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 底部提示条（断网 / 加载失败）

private struct NoticeBanner: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 4)
            Button("重试") { retry() }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.24))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.94))
        )
        .padding(.horizontal, 16)
    }
}

#Preview {
    RootView()
}
