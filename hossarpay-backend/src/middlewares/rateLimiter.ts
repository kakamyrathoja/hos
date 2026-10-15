import rateLimit from 'express-rate-limit';

// Genel hız sınırı: tüm /api istekleri — IP başına 300 istek / 15 dk
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { message: 'Çok fazla istek. Lütfen daha sonra tekrar deneyin.' },
});

// Kimlik doğrulama denemeleri: 10 deneme / 15 dk (brute-force koruması)
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { message: 'Çok fazla giriş denemesi. 15 dakika sonra tekrar deneyin.' },
});

// İçerik gönderimi: 60 mesaj/hikaye / 15 dk (spam koruması)
export const contentLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 60,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { message: 'Çok fazla içerik gönderildi. Lütfen bekleyin.' },
});

// Şikayet/engelleme: 30 işlem / 15 dk (şikayet spam'i koruması)
export const reportLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { message: 'Çok fazla işlem. Lütfen bekleyin.' },
});