import SwiftUI
import AVKit

struct SplashView: View {
    @Binding var showSplash: Bool
    
    // Player nesnemizi oluşturuyoruz
    @State private var player = AVPlayer()
    
    var body: some View {
        ZStack {
            // Arka plan rengini sizin verdiğiniz Hex (#1F2123) tonu ile ayarlıyoruz
            Color(red: 31/255, green: 33/255, blue: 35/255) // #1F2123 karşılığı
                .ignoresSafeArea() // Dynamic Island ve alt kısımlara tam yayılması için
            
            VStack(spacing: 30) {
                // Video görünümü (Ellerin kırpılmaması için aspect ayarlandı)
                VideoPlayerView(player: player)
                    .frame(maxWidth: .infinity, maxHeight: 500)
                    .padding(.horizontal, 10) // Kenarlardan çok hafif boşluk ki eller ekrana yapışmasın
                
                Text("Hoş Geldiniz!")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            setupAndPlayVideo()
            
            // 4 saniye sonra ana ekrana geçiş (Eğer videonuz daha uzunsa veya kısaysa buradaki 4.0 rakamını değiştirebilirsiniz)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.8)) {
                    showSplash = false
                    player.pause() // Geçiş yapınca sesi/videoyu durdur
                }
            }
        }
    }
    
    private func setupAndPlayVideo() {
        // "splash_video" adlı mp4 dosyasını projenin içinden bul
        if let url = Bundle.main.url(forResource: "splash_video", withExtension: "mp4") {
            player = AVPlayer(url: url)
            player.play()
        }
    }
}

// Oynatma kontrolleri (play, pause eklentileri vs.) çıkmadan çok temiz video oynatmak için özel UIKit görünümü
class PlayerUIView: UIView {
    var playerLayer: AVPlayerLayer
    
    init(player: AVPlayer) {
        playerLayer = AVPlayerLayer(player: player)
        super.init(frame: .zero)
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

struct VideoPlayerView: UIViewRepresentable {
    var player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerUIView {
        return PlayerUIView(player: player)
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}
