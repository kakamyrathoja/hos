import { Request, Response } from 'express';
import { uploadToStorage, deleteFromStorage, getSignedFileUrl } from '../utils/r2';

// Genel dosya yükleme endpoint'i
export const uploadFile = async (req: Request, res: Response): Promise<void> => {
  try {
    if (!req.file) {
      res.status(400).json({ message: 'Dosya bulunamadi' });
      return;
    }

    const folder = (req.body.folder as string) || 'general';

    // B2'ye yükle
    const key = await uploadToStorage(
      req.file.buffer,
      req.file.originalname,
      req.file.mimetype,
      folder
    );

    // Signed URL (1 saat geçerli)
    const url = await getSignedFileUrl(key, 3600);

    res.status(200).json({
      message: 'Dosya basariyla yuklendi',
      key,
      url,
      size: req.file.size,
      mimetype: req.file.mimetype,
    });
  } catch (error: any) {
    console.error('Upload error:', error);
    res.status(500).json({ message: 'Dosya yuklenemedi', error: error.message });
  }
};

// Dosya sil
export const deleteFile = async (req: Request, res: Response): Promise<void> => {
  try {
    const { key } = req.params;

    if (!key) {
      res.status(400).json({ message: 'Dosya anahtari (key) gerekli' });
      return;
    }

    await deleteFromStorage(key);

    res.status(200).json({ message: 'Dosya silindi' });
  } catch (error: any) {
    console.error('Delete error:', error);
    res.status(500).json({ message: 'Dosya silinemedi', error: error.message });
  }
};

// Dosya URL'ini yenile (signed URL)
export const refreshFileUrl = async (req: Request, res: Response): Promise<void> => {
  try {
    const { key } = req.params;

    if (!key) {
      res.status(400).json({ message: 'Dosya anahtari (key) gerekli' });
      return;
    }

    const url = await getSignedFileUrl(key, 3600);

    res.status(200).json({ key, url, expiresIn: 3600 });
  } catch (error: any) {
    console.error('Refresh URL error:', error);
    res.status(500).json({ message: 'URL yenilenemedi', error: error.message });
  }
};