# Runny

Runny, spor aktivitelerini kaydetmeyi ve rotaları sosyal olarak paylaşmayı sağlayan Flutter uygulamasıdır.

## Şu anki durum

- Flutter iOS, Android ve Web projesi
- Akış, keşfet, aktivitelerim ve profil ekranları
- Aktivite türü seçim menüsü
- GPS aktivite kaydı (OpenStreetMap)
- Supabase Auth: e-posta, Google, Apple
- Başlangıç şeması: `supabase/schema.sql`

## Supabase bağlama

Varsayılan bağlantı `assets/config/app.env` içinden okunur — düz `flutter run` yeterlidir.

İsteğe bağlı override:

```bash
flutter run --dart-define-from-file=.env
```

veya yerel `.env` / `supabase/config.local.json` dosyaları (git’e girmez).

SQL Editor’da `supabase/schema.sql` içeriğini çalıştır.

Google ve Apple girişleri için Dashboard → Authentication → Providers ayarını ayrıca açman gerekir.

E-posta doğrulama şablonu ve Site URL ayarı: `supabase/email_templates/SETUP.md`

Profil detay alanları için SQL: `supabase/migrations/002_profile_details.sql`

Spor hedefleri için SQL: `supabase/migrations/005_sport_goals.sql`

## Kontroller

```bash
flutter analyze
flutter test
```
