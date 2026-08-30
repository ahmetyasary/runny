---
name: simulatorlere-gonder
description: >-
  Kullanıcı "Simulatörlere gönder." veya "Simulatörlere gönder" dediğinde
  çalıştır. Önce iPhone simülatörde Runny'yi başlat, sonra Apple Watch
  simülatörde RunnyWatch'u başlat. Sıra zorunlu: iPhone → Watch.
disable-model-invocation: false
---

# Simulatörlere gönder

Kullanıcı bu komutu verdiğinde **hemen** şu sırayı uygula. Sıra değişmez.

## Zorunlu sıra

1. **Önce iPhone** simülatörü aç / boot et ve Runny'yi başlat
2. iPhone uygulaması ayağa kalkana kadar bekle
3. **Sonra Watch** simülatörü aç / boot et ve RunnyWatch'u başlat

## Nasıl çalıştır

Proje kökünden scripti çalıştır (tercih edilen yol):

```bash
bash scripts/launch_simulators.sh
```

Script yoksa veya başarısızsa aynı sırayı elle uygula:

1. iPhone device id bul (`flutter devices` / `xcrun simctl list devices booted`)
2. `flutter run -d <iphone-id>` (arka planda) — Syncing / Flutter run key commands gelene kadar bekle
3. Watch app build varsa: `xcrun simctl install <watch-id> …` + `xcrun simctl launch <watch-id> com.smartlogy.runny.watchkitapp`
4. Yoksa `xcodebuild … -scheme RunnyWatch` ile build edip kur / launch

## Cihaz ipuçları (Runny)

- iPhone bundle: `com.smartlogy.runny`
- Watch bundle: `com.smartlogy.runny.watchkitapp`
- Tipik sim çift: iPhone 17 Pro + eşli Apple Watch Ultra

## Yanıt

Türkçe, kısa: iPhone başladı → Watch başladı. Hata varsa hangi adımda olduğunu söyle.
