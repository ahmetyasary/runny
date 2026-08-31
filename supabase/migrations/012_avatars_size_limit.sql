-- Avatar yükleme limiti: 5MB → 10MB (büyük galeri fotoğrafları için güvenlik payı)
update storage.buckets
set
  file_size_limit = 10485760,
  allowed_mime_types = array[
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif'
  ]
where id = 'avatars';
