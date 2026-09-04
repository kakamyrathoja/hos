import nodemailer from 'nodemailer';
import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../index';

const JWT_SECRET = process.env.JWT_SECRET || 'secret';


const generateReferralCode = (name: string): string => {
  const prefix = name.substring(0, 3).toUpperCase();
  const randomNum = Math.floor(1000 + Math.random() * 9000);
  return `${prefix}${randomNum}`;
};

export const register = async (req: Request, res: Response): Promise<void> => {
  try {
    const { firstName, lastName, nickname, email, verificationCode, password, referralCode, fcmToken } = req.body;

    if (!firstName || !lastName || !nickname || !email || !password) {
      res.status(400).json({ message: 'Lütfen tüm alanları doldurun.' }); return;
    }

    if (String(password).length < 8) {
      res.status(400).json({ message: 'Şifre en az 8 karakter uzunluğunda olmalıdır.' }); return;
    }

    const nameRegex = /^[a-zA-ZğüşıöçĞÜŞİÖÇÄäŽžŇňÝýА-Яа-я\s]{2,50}$/;
    if (!nameRegex.test(String(firstName).trim()) || !nameRegex.test(String(lastName).trim())) {
      res.status(400).json({ message: 'Lütfen geçerli bir ad ve soyad girin.' }); return;
    }
    
    // Nickname bosluk veya ozel isaret icermesin, sadece harf ve rakam
    const nickRegex = /^[a-zA-Z0-9_]{3,20}$/;
    if (!nickRegex.test(String(nickname).trim())) {
      res.status(400).json({ message: 'Kullanıcı adı sadece harf, rakam ve alt çizgi (_) içerebilir ve en az 3 karakter olmalıdır.' }); return;
    }

    if (!verificationCode) { res.status(400).json({ message: 'Doğrulama kodu gerekli' }); return; }

    const existingEmail = await prisma.user.findUnique({ where: { email: String(email) } });
    if (existingEmail) { res.status(400).json({ message: 'Bu e-posta kullanımda' }); return; }

    const existingNick = await (prisma as any).user.findFirst({ where: { nickname: { equals: String(nickname).trim(), mode: 'insensitive' } }});
    if (existingNick) { res.status(400).json({ message: 'Bu kullanıcı adı (nickname) zaten alınmış' }); return; }

    const validCode = await (prisma as any).verificationCode.findFirst({
      where: { email: String(email), code: String(verificationCode), expiresAt: { gt: new Date() } }
    });
    if (!validCode) { res.status(400).json({ message: 'Geçersiz veya süresi dolmuş kod' }); return; }

    let refUserId = null;
    let initialBalance = 0.00;

    if (referralCode) {
      const refUser = await prisma.user.findUnique({ where: { referralCode: String(referralCode) } });
      if (refUser) {
         refUserId = refUser.id;
         initialBalance = 10.00; 
         await prisma.user.update({ where: { id: refUser.id }, data: { balance: { increment: 5.00 } } });
      }
    }

    const newRefCode = generateReferralCode(String(firstName));
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(String(password), salt);

    const newUser = await prisma.user.create({
      data: {
        firstName: String(firstName).trim(),
        lastName: String(lastName).trim(),
        nickname: String(nickname).trim(),
        phoneNumber: `+MAIL${Date.now()}`,
        email: String(email).trim(),
        isEmailVerified: true,
        passwordHash,
        balance: initialBalance,
        referralCode: newRefCode,
        referredBy: refUserId,
        fcmToken: fcmToken ? String(fcmToken) : null
      },
    });

    const token = jwt.sign({ id: newUser.id, role: newUser.role }, JWT_SECRET, { expiresIn: '30d' });

    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: {
        id: newUser.id,
        firstName: newUser.firstName,
        lastName: newUser.lastName,
        phoneNumber: newUser.phoneNumber,
        nickname: newUser.nickname,
        balance: newUser.balance,
      },
    });
  } catch (error: any) {
    console.error('LOGIN/REGISTER HATA:', error);
    res.status(500).json({ message: 'Server error', error: error.message || error });
  }
};

export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    const { nickname, password, fcmToken } = req.body;

    if (!nickname || !password) { res.status(400).json({ message: 'Kullanıcı adı ve şifre zorunludur' }); return; }

    let user = await (prisma as any).user.findFirst({ 
      where: { nickname: { equals: String(nickname).trim(), mode: 'insensitive' } } 
    });

    if (!user) {
      res.status(400).json({ message: 'Geçersiz kullanıcı adı veya şifre' });
      return;
    }

    if ((user.role as string) === 'BANNED') {
      res.status(403).json({ message: 'Hesabınız askıya alınmıştır. Lütfen destek ile iletişime geçin.' });
      return;
    }

    const isMatch = await bcrypt.compare(String(password), user.passwordHash);
    if (!isMatch) {
      res.status(400).json({ message: 'Geçersiz kullanıcı adı veya şifre' });
      return;
    }

    if (fcmToken && String(fcmToken) !== user.fcmToken) {
      user = await prisma.user.update({
        where: { id: user.id },
        data: { fcmToken: String(fcmToken) }
      });
    }

    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });

    res.status(200).json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        firstName: user.firstName,
        lastName: user.lastName,
        phoneNumber: user.phoneNumber,
        nickname: user.nickname,
        role: user.role,
        balance: user.balance,
      },
    });
  } catch (error: any) {
    console.error('LOGIN/REGISTER HATA:', error);
    res.status(500).json({ message: 'Server error', error: error.message || error });
  }
};

export const telegramAuth = async (req: Request, res: Response): Promise<void> => {
  try {
    const { tgId, firstName, lastName, username } = req.body;
    if (!tgId) { res.status(400).json({ message: 'Telegram ID zorunludur' }); return; }

    let user = await (prisma as any).user.findFirst({ where: { telegramId: String(tgId) } });

    // Kullanici yoksa Telegram bilgileriyle arka planda otomatik kayit edelim
    if (!user) {
      const salt = await bcrypt.genSalt(10);
      const passwordHash = await bcrypt.hash(String(tgId) + 'tg_secret', salt);
      const mockPhone = `+TG${tgId}`; // Telegram'dan girenlerin gecici numarasi

      user = await (prisma as any).user.create({
        data: {
          firstName: String(firstName || 'Telegram'),
          lastName: lastName ? String(lastName) : '',
          nickname: username ? String(username) : null,
          phoneNumber: mockPhone,
          telegramId: String(tgId),
          passwordHash,
        }
      });
    }

    if (!user) { res.status(500).json({ message: 'Kullanıcı oluşturulamadı.' }); return; }
    if ((user.role as string) === 'BANNED') {
      res.status(403).json({ message: 'Hesabınız askıya alınmıştır.' }); return;
    }

    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });

    res.status(200).json({
      message: 'Telegram Login successful',
      token,
      user: {
        id: user.id,
        firstName: user.firstName,
        lastName: user.lastName,
        phoneNumber: user.phoneNumber,
        nickname: user.nickname,
        role: user.role,
        balance: user.balance,
      },
    });
  } catch (error: any) {
    console.error('TELEGRAM AUTH ERROR:', error);
    res.status(500).json({ message: 'Server error', error: error.message || error });
  }
};

export const sendVerificationEmail = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email } = req.body;
    if (!email) { res.status(400).json({ message: 'E-posta zorunludur' }); return; }

    const existingUser = await prisma.user.findUnique({ where: { email: String(email) } });
    if (existingUser) {
      res.status(400).json({ message: 'Bu e-posta zaten kayıtlı.' }); return;
    }

    const code = Math.floor(1000 + Math.random() * 9000).toString(); // 4 haneli kod
    const expiresAt = new Date(Date.now() + 10 * 60000); // 10 dakika geçerli

    await (prisma as any).verificationCode.create({
      data: { email: String(email), code, expiresAt }
    });

    // Gerçek E-Posta Gönderimi (NodeMailer & Gmail)
    const transporter = nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 465,
      secure: true,
      auth: { 
        user: process.env.EMAIL_USER, 
        pass: process.env.EMAIL_PASS 
      }
    });

    const mailOptions = {
      from: '"Hossarpay Support" <' + process.env.EMAIL_USER + '>',
      to: email,
      subject: 'Hossarpay - Doğrulama Kodunuz',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
          <h2 style="color: #0066FF; text-align: center;">Hossarpay'e Hoş Geldiniz!</h2>
          <p style="font-size: 16px; color: #333;">Hesabınızı doğrulamak için aşağıdaki 4 haneli güvenlik kodunu kullanın:</p>
          <div style="text-align: center; margin: 30px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #0066FF; padding: 15px 30px; background-color: #f0f7ff; border-radius: 8px;">${code}</span>
          </div>
          <p style="font-size: 14px; color: #666;">Bu kod 10 dakika boyunca geçerlidir. Lütfen bu kodu kimseyle paylaşmayın.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
          <p style="font-size: 12px; color: #999; text-align: center;">© 2026 Hossarpay. Tüm Hakları Saklıdır.</p>
        </div>
      `
    };

    await new Promise((resolve, reject) => {
      transporter.sendMail(mailOptions, (err, info) => {
        if (err) {
          console.error("Nodemailer Hatası:", err);
          reject(err);
        } else {
          console.log(`[EMAIL BAŞARIYLA GÖNDERİLDİ] Alıcı: ${email}`);
          resolve(info);
        }
      });
    });

    res.status(200).json({ message: 'Doğrulama kodu gönderildi.' });
  } catch (error: any) {
    console.error('EMAIL SEND ERROR:', error);
    res.status(500).json({ message: 'E-posta gönderilemedi', error: error.message || error });
  }
};

export const googleAuth = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, firstName, lastName, photoUrl, googleId } = req.body;
    if (!email) { res.status(400).json({ message: 'E-Posta zorunludur' }); return; }

    let user = await (prisma as any).user.findUnique({ where: { email: String(email) } });

    // Kullanici yoksa Google bilgileriyle arka planda otomatik kayit edelim
    if (!user) {
      const salt = await bcrypt.genSalt(10);
      const passwordHash = await bcrypt.hash(String(email) + 'google_secret', salt);
      const mockPhone = `+GL${Date.now().toString().substring(0, 8)}`; // Gecici numara
      const newRefCode = generateReferralCode(String(firstName || 'Google'));

      user = await (prisma as any).user.create({
        data: {
          firstName: String(firstName || 'Google'),
          lastName: lastName ? String(lastName) : '',
          nickname: String(email).split('@')[0].substring(0, 15),
          phoneNumber: mockPhone,
          email: String(email),
          isEmailVerified: true,
          profileImage: photoUrl ? String(photoUrl) : null,
          passwordHash,
          referralCode: newRefCode,
        }
      });
    }

    if ((user.role as string) === 'BANNED') {
      res.status(403).json({ message: 'Hesabınız askıya alınmıştır.' }); return;
    }

    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });

    res.status(200).json({
      message: 'Google Login successful',
      token,
      user: {
        id: user.id,
        firstName: user.firstName,
        lastName: user.lastName,
        phoneNumber: user.phoneNumber,
        nickname: user.nickname,
        email: user.email,
        profileImage: user.profileImage,
        role: user.role,
        balance: user.balance,
      },
    });
  } catch (error: any) {
    console.error('GOOGLE AUTH ERROR:', error);
    res.status(500).json({ message: 'Server error', error: error.message || error });
  }
};

