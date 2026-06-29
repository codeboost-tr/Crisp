import SwiftUI
import CrispCore

public struct LicenseView: View {
    @Environment(LicenseStore.self) private var licenseStore
    @State private var licenseKey: String = ""
    @State private var isActivating: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Crisp Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            switch licenseStore.state {
            case .trial(let daysLeft):
                Text("You are on a free trial.")
                    .font(.headline)
                Text("\(daysLeft) days remaining")
                    .foregroundColor(.secondary)
            case .active:
                Text("License Active")
                    .font(.headline)
                    .foregroundColor(.green)
            case .offlineGrace(let daysLeft):
                Text("Offline Mode (Grace Period)")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text("\(daysLeft) days remaining until re-validation is required.")
                    .font(.subheadline)
            case .expired(let message), .invalid(let message):
                Text(message)
                    .font(.headline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            case .checking:
                ProgressView("Checking license status...")
            }
            
            if !licenseStore.state.isUsable || (ifCaseTrial(licenseStore.state)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter License Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("POLAR-XXX-XXX", text: $licenseKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isActivating)
                    
                    HStack {
                        Spacer()
                        Button(action: activate) {
                            if isActivating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Activate")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(licenseKey.isEmpty || isActivating)
                    }
                }
                .padding(.top, 16)
            }
            
            if case .active = licenseStore.state {
                Button("Deactivate License", role: .destructive) {
                    licenseStore.deactivate()
                }
                .padding(.top, 16)
            }
        }
        .padding(32)
        .frame(width: 400)
    }
    
    private func activate() {
        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        
        isActivating = true
        Task {
            await licenseStore.activate(key: trimmedKey)
            isActivating = false
        }
    }
    
    private func ifCaseTrial(_ state: LicenseStore.State) -> Bool {
        if case .trial = state { return true }
        return false
    }
}

#Preview {
    LicenseView()
        .environment(LicenseStore())
}
