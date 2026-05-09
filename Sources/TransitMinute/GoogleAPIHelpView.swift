import SwiftUI

struct GoogleAPIHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Create a Google API key")
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HelpStep(number: 1, text: "Open Google Cloud Console and create or select a project.")
                    HelpStep(number: 2, text: "Open APIs & Services, then enable Places API and Routes API.")
                    HelpStep(number: 3, text: "Open Credentials and create an API key.")
                    HelpStep(number: 4, text: "Restrict the key to Places API and Routes API. For a local test build, leave application restrictions unset until the app bundle identifier is finalized.")
                    HelpStep(number: 5, text: "Paste the key into Transit Minute and save it.")

                    if let credentialsURL = URL(string: "https://console.cloud.google.com/google/maps-apis/credentials") {
                        Link(destination: credentialsURL) {
                            Label("Open Google Cloud credentials", systemImage: "safari")
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
    }
}

private struct HelpStep: View {
    var number: Int
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .frame(width: 28, height: 28)
                .background(.blue.opacity(0.14), in: Circle())
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
