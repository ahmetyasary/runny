# Apple Watch kurulumu

Flutter watchOS derlemez. Saat tarafı native SwiftUI; telefon ↔ saat `WatchConnectivity` ile konuşur.

## Hazır olanlar

- Flutter: `lib/features/watch/` (`WatchBridge`, senkron, durum ekranı)
- iOS: `Runner/AppDelegate.swift` içinde WCSession + MethodChannel (`com.runny/watch`)
- watchOS kaynakları: `ios/RunnyWatch/RunnyWatchApp.swift`

## Xcode’da Watch target ekle (bir kez)

1. `ios/Runner.xcworkspace` dosyasını Xcode ile aç.
2. **File → New → Target… → watchOS → App**
3. Product Name: `RunnyWatch`
4. Bundle ID: `com.example.runny.watchkitapp` (companion: `com.example.runny`)
5. Embed: **Watch App for Existing Application → Runner**
6. Oluşan varsayılan Swift dosyalarını sil; yerine `ios/RunnyWatch/RunnyWatchApp.swift` dosyasını target’a ekle.
7. Watch target Info.plist’e `WKCompanionAppBundleIdentifier = com.example.runny` koy.
8. Gerçek cihazda dene (Simulator’da WCSession kısıtlıdır).

## Çalışma

- Telefonda aktivite başlayınca süre/mesafe saate gider.
- Saatte **Koşu başlat / Bitir** telefona komut yollar.
- Uygulamada: **Profil → ⚙️ → Apple Watch**
