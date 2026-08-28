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

1. Ortam dosyasını oluştur:

```bash
cp .env.example .env
```

2. `.env` içine URL ve publishable key değerlerini yaz (`.env` git’e girmez).

Alternatif: `supabase/config.local.example.json` → `supabase/config.local.json`

3. SQL Editor’da `supabase/schema.sql` içeriğini çalıştır.

4. Uygulamayı başlat:

```bash
flutter run --dart-define-from-file=.env
```

veya:

```bash
flutter run --dart-define-from-file=supabase/config.local.json
```

Google ve Apple girişleri için Dashboard → Authentication → Providers ayarını ayrıca açman gerekir.

E-posta doğrulama şablonu ve Site URL ayarı: `supabase/email_templates/SETUP.md`

Profil detay alanları için SQL: `supabase/migrations/002_profile_details.sql`

## Kontroller

```bash
flutter analyze
flutter test
```
