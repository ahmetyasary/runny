# Runny e-posta doğrulama ayarları

E-posta şablonları Dashboard üzerinden güncellenir (API anahtarıyla otomatik yazılamaz).

## 1) Site URL ve Redirect (localhost’u kaldır)

Dashboard → **Authentication** → **URL Configuration**

- **Site URL:** `https://lidosubbhgrxhvgkshdr.supabase.co`
- **Redirect URLs** listesine ekle:
  - `https://lidosubbhgrxhvgkshdr.supabase.co`
  - `https://lidosubbhgrxhvgkshdr.supabase.co/**`

`http://localhost...` varsa kaldır veya bırakma.

## 2) Gönderen adı

Dashboard → **Authentication** → **Emails** (veya Project Settings → Auth)

- **Sender name / From name:** `Runny`
- Mümkünse From adresi de Runny’yi düşündürecek şekilde kalsın (varsayılan Supabase mail’de domain sınırlıdır; özel domain sonra SMTP ile gelir).

## 3) Confirm signup şablonu

Dashboard → **Authentication** → **Email Templates** → **Confirm sign up**

- **Subject:** `Runny — e-posta adresini doğrula`
- **Body:** `confirm_signup.html` içeriğinin tamamını yapıştır ve kaydet.

## 4) Test

1. Uygulamada yeni bir e-posta ile kayıt ol.
2. Gelen kutuda konu satırında **Runny** görünmeli.
3. Linke tıklayınca önce Supabase verify, sonra Site URL’e yönlenmeli (localhost değil).
4. Uygulamaya dönüp **Giriş yap**.
