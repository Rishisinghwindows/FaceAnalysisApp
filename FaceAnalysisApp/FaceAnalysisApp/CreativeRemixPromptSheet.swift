import SwiftUI

struct CreativeRemixPromptSheet: View {
    @Binding var prompt: String
    let isGenerating: Bool
    let errorMessage: String?
    let onGenerate: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Creative Remix")
                    .font(.system(size: 22, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Describe the vibe…", text: $prompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button(action: onGenerate) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.primaryPink)
                            .frame(height: 52)
                        if isGenerating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Generate")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
        }
    }
}
