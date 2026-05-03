import SwiftUI

struct BackupView: View {
    var body: some View {
        Text("Backup")
            .padding()
    }
}

#if DEBUG
struct BackupView_Previews: PreviewProvider {
    static var previews: some View { BackupView() }
}
#endif
