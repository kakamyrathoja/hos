import bcrypt from 'bcryptjs';
import { Response } from 'express';
import { prisma } from '../index';
import { AuthRequest } from '../middlewares/authMiddleware';

export const syncContacts = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { phones } = req.body; 

    if (!userId || !phones || !Array.isArray(phones)) {
      res.status(400).json({ message: 'Geçersiz veri.' }); return;
    }

    let addedCount = 0;

    for (const p of phones) {
      if (!p.phone) continue;
      let cleanPhone = String(p.phone).replace(/\D/g, ''); 
      if (cleanPhone.length > 8) {
        cleanPhone = cleanPhone.slice(-8); 
      }
      if (cleanPhone.length < 5) continue; 

      const foundUser = await prisma.user.findFirst({
        where: { phoneNumber: { endsWith: cleanPhone } }
      });

      if (foundUser && foundUser.id !== userId) {
        // YENİ: Vercel'in TypeScript derleyicisini atlamak için köşeli parantez kullanıldı. 
        // Bu Prisma'nın "Contact" tablosunu bulamama hatasını KESİN ÇÖZER.
        await (prisma as any)['contact'].upsert({
          where: { userId_contactUserId: { userId, contactUserId: foundUser.id } },
          update: { savedName: String(p.name) },
          create: { userId, contactUserId: foundUser.id, savedName: String(p.name) }
        });
        addedCount++;
      }
    }

    res.status(200).json({ message: 'Senkronizasyon tamamlandı.', matchedCount: addedCount });
  } catch (error: any) { 
    console.error("SYNC CONTACTS ERROR:", error);
    res.status(500).json({ message: 'Sync error', details: error.message || error }); 
  }
};

export const getContacts = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    if (!userId) { res.status(401).json({ message: 'Unauthorized' }); return; }

    const contacts = await (prisma as any)['contact'].findMany({
      where: { userId },
      include: {
        contactUser: { select: { id: true, firstName: true, nickname: true, profileImage: true, phoneNumber: true } }
      }
    });

    res.status(200).json(contacts);
  } catch (error: any) { 
    console.error("GET CONTACTS ERROR:", error);
    res.status(500).json({ message: 'Get contacts error', details: error.message || error }); 
  }
};

export const getProfile = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true, firstName: true, lastName: true, nickname: true, phoneNumber: true, 
        email: true, balance: true, profileImage: true, role: true, fcmToken: true, createdAt: true,
      }
    });
    if (!user) { res.status(404).json({ message: 'User not found' }); return; }
    res.status(200).json(user);
  } catch (error: any) { 
    console.error("GET PROFILE ERROR:", error);
    res.status(500).json({ message: 'Profile error', details: error.message || error }); 
  }
};

export const updateProfile = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { nickname, email, profileImage, fcmToken } = req.body;
    const dataToUpdate: any = {};
    if (nickname !== undefined) dataToUpdate.nickname = nickname;
    if (email !== undefined) dataToUpdate.email = email;
    if (profileImage !== undefined) dataToUpdate.profileImage = profileImage;
    if (fcmToken !== undefined) dataToUpdate.fcmToken = fcmToken;

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: dataToUpdate,
      select: { nickname: true, email: true, profileImage: true, fcmToken: true }
    });
    res.status(200).json({ message: 'Profil güncellendi', user: updatedUser });
  } catch (error: any) {
    console.error("UPDATE PROFILE ERROR:", error);
    if (error.code === 'P2002') res.status(400).json({ message: 'Bu takma ad veya e-posta kullanımda.' });
    else res.status(500).json({ message: 'Update error', details: error.message || error });
  }
};

export const searchUser = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { query } = req.query; 
    const currentUserId = req.user?.id;
    if (!query) { res.status(400).json({ message: 'Arama boş olamaz.' }); return; }

    const qString = String(query).trim();
    
    // Eğer aranan kelimede + işareti varsa (örnek: +99362...), büyük ihtimalle tam numaradır.
    // O yüzden "equals" da ekleyerek Prisma'nın arama yapmasını kolaylaştıralım.
    const users = await prisma.user.findMany({
      where: { 
        OR: [ 
          { phoneNumber: qString }, // Tam eşleşme (Eski ve %100 çalışan sistem)
          { phoneNumber: { contains: qString } }, // Kısmi eşleşme (62123456 yazarsa bulması için)
          { nickname: { equals: qString, mode: 'insensitive' } }, // Lakap ile tam eşleşme
          { nickname: { contains: qString, mode: 'insensitive' } }, // Lakap ile kısmi eşleşme
          { firstName: { contains: qString, mode: 'insensitive' } }
        ] 
      },
      select: { id: true, firstName: true, lastName: true, nickname: true, profileImage: true, phoneNumber: true },
      take: 10
    });

    // Kendini filtrele
    const filteredUsers = users.filter(u => u.id !== currentUserId);

    if (filteredUsers.length === 0) { res.status(404).json({ message: 'Kullanıcı bulunamadı.' }); return; }

    res.status(200).json(filteredUsers);
  } catch (error: any) { 
    console.error("SEARCH USER ERROR:", error);
    res.status(500).json({ message: 'Search error', details: error.message || error }); 
  }
};



export const secureAccount = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { phoneNumber, password } = req.body;

    if (!userId || !phoneNumber || !password) {
       res.status(400).json({ message: 'Eksik bilgi' }); return;
    }

    const cleanPhone = String(phoneNumber).trim().replace(/\s/g, '');
    
    // Numara baskasinda var mi kontrol et
    const existing = await prisma.user.findUnique({ where: { phoneNumber: cleanPhone } });
    if (existing && existing.id !== userId) {
      res.status(400).json({ message: 'Bu telefon numarası zaten kullanımda.' }); return;
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(String(password), salt);

    const updated = await prisma.user.update({
      where: { id: userId },
      data: {
        phoneNumber: cleanPhone,
        passwordHash: passwordHash
      },
      select: { id: true, firstName: true, lastName: true, nickname: true, phoneNumber: true, balance: true, role: true, profileImage: true }
    });

    res.status(200).json({ message: 'Hesap güvenceye alındı', user: updated });
  } catch (error: any) {
    console.error("SECURE ACCOUNT ERROR:", error);
    res.status(500).json({ message: 'Server error', details: error.message || error });
  }
};