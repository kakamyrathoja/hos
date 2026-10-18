import multer from 'multer';
import path from 'path';
import crypto from 'crypto';

// Memory storage - dosyayı buffer olarak al (B2'ye yollamak için)
const storage = multer.memoryStorage();

// Dosya boyutu limiti (10 MB)
export const upload = multer({
  storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10 MB
  },
  fileFilter: (req, file, cb) => {
    // İzin verilen tipler
    const allowed = /jpeg|jpg|png|gif|webp|mp4|mov|webm|pdf/;
    const extname = allowed.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowed.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Sadece resim, video ve PDF dosyalari yuklenebilir!'));
    }
  },
});

// Belirli alanlar için upload middleware'leri
export const uploadAvatar = upload.single('avatar');
export const uploadMedia = upload.single('media');
export const uploadMultiple = upload.array('files', 5); // max 5 dosya