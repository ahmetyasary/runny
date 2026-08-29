# Apple Watch — gerçek cihaza yükleme

## Önemli

iPhone’daki **Saat uygulaması → Uygulamalar → Yükle** geliştirici (debug) build’lerde sık başarısız olur.
Watch’u **Xcode ile** yükle.

## Adımlar

1. Apple Watch iPhone’a eşli, Bluetooth açık, ikisi de açık/kilitli değil.
2. Mac’te:
   ```bash
   open ios/Runner.xcworkspace
   ```
3. Üstten scheme: **Runner**
4. Destination: **Ahmet’s iPhone** (fiziksel)
5. **Product → Clean Build Folder**, sonra ▶ **Run**
6. iPhone’a kurulunca Watch companion da gider.
7. Saatte uyarı çıkarsa: **Ayarlar → Genel → VPN ve Cihaz Yönetimi / Geliştirici** → güven.

Alternatif: Scheme **RunnyWatch**, destination fiziksel **Apple Watch** → Run.

## Bundle ID’ler (doğru olmalı)

| Hedef | Bundle ID |
|--------|-----------|
| iPhone | `com.smartlogy.runny` |
| Watch | `com.smartlogy.runny.watchkitapp` |
| Companion key | `WKCompanionAppBundleIdentifier = com.smartlogy.runny` |

## Hâlâ yüklenmezse

```bash
# Telefondan uygulamayı sil, saatten de sil
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
```

Sonra Xcode’dan tekrar Run.
