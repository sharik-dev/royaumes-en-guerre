import SwiftUI

struct OceanTransitView: View {
    @State private var boatY: CGFloat = -15

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.0, green: 0.15, blue: 0.45),
                         Color(red: 0.0, green: 0.35, blue: 0.65)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                Text("🚢")
                    .font(.system(size: 90))
                    .offset(y: boatY)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: boatY)
                VStack(spacing: 8) {
                    Text("🌊 Voyage en bateau")
                        .font(.custom("Georgia", size: 26))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Traversée de l'océan en cours…")
                        .foregroundColor(.white.opacity(0.75))
                    Text("Appuyez pour continuer")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.top, 4)
                }
                Spacer()
            }
        }
        .onAppear { boatY = 15 }
    }
}
