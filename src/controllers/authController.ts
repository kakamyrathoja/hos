import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../index';

const JWT_SECRET = process.env.JWT_SECRET || 'secret';

const generateReferralCode = (name: string): string => {
  const prefix = name.substring(0, 3).toUpperCase();
  const randomNum = Math.floor(1000 + Math.random() * 9000);
  return prefix + randomNum;
};

const generateNickname = (email: string, firstName: string): string => {
  const base = (email.split('@')[0] || firstName || 'user')
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, '')
    .substring(0, 15);
  const random = Math.floor(100 + Math.random() * 900);
  return base + random;
};

const findUniqueNickname = async (email: string, firstName: string): Promise<string> => {
  for (let i = 0; i < 5; i++) {
    const candidate = generateNickname(email, firstName);
    const existing = await (prisma as any).user.findFirst({
      where: { nickname: { equals: candidate, mode: 'insensitive' } }
    });
    if (!existing) return candidate;
  }
  return generateNickname(email, firstName) + Date.now().toString().slice(-4);
};

export const register = async (req: Request, res: Response): Promise<void> => {
  try {
    const { firstName, lastName, email, verificationCode, password, referralCode, fcmToken, nickname: providedNick } = req.body;

    if (!firstName || !lastName || !email || !password) {
      res.status(400).json({ message: 'Lutfen tum alanlari doldurun.' });
      return;
    }

    if (String(password).length < 8) {
      res.status(400).json({ message: 'Sifre en az 8 karakter uzunlugunda olmalidir.' });
      return;
    }

    const nameRegex = /^[a-zA-Z\s]{2,50}$/;
    if (!nameRegex.test(String(firstName).trim()) || !nameRegex.test(String(lastName).trim())) {
      res.status(400).json({ message: 'Lutfen gecerli bir ad ve soyad girin.' });
      return;
    }

    if (!verificationCode) {
      res.status(400).json({ message: 'Dogrulama kodu gerekli' });
      return;
    }

    const normalizedEmail = String(email).trim().toLowerCase();

    const existingEmail = await prisma.user.findUnique({ where: { email: normalizedEmail } });
    if (existingEmail) {
      res.status(400).json({ message: 'Bu e-posta kullanımda' });
      return;
    }

    const validCode = await (prisma as any).verificationCode.findFirst({
      where: { email: normalizedEmail, code: String(verificationCode), expiresAt: { gt: new Date() } }
    });
    if (!validCode) {
      res.status(400).json({ message: 'Gecersiz veya suresi dolmus kod' });
      return;
    }

    let finalNickname: string;
    if (providedNick) {
      const nickRegex = /^[a-zA-Z0-9_]{3,20}$/;
      const trimmed = String(providedNick).trim();
      if (!nickRegex.test(trimmed)) {
        res.status(400).json({ message: 'Kullanici adi sadece harf, rakam ve alt cizgi (_) icerebilir ve en az 3 karakter olmalidir.' });
        return;
      }
      const existingNick = await (prisma as any).user.findFirst({
        where: { nickname: { equals: trimmed, mode: 'insensitive' } }
      });
      if (existingNick) {
        res.status(400).json({ message: 'Bu kullanici adi (nickname) zaten alinmis' });
        return;
      }
      finalNickname = trimmed;
    } else {
      finalNickname = await findUniqueNickname(normalizedEmail, String(firstName));
    }

    let refUserId: string | null = null;
    let initialBalance = 0.00;

    if (referralCode) {
      const refUser = await prisma.user.findUnique({ where: { referralCode: String(referralCode) } });
      if (refUser) {
        refUserId = refUser.id;
        initialBalance = 10.00;
        await prisma.user.update({
          where: { id: refUser.id },
          data: { balance: { increment: 5.00 } }
        });
      }
    }

    const newRefCode = generateReferralCode(String(firstName));
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(String(password), salt);

    const newUser = await prisma.user.create({
      data: {
        firstName: String(firstName).trim(),
        lastName: String(lastName).trim(),
        nickname: finalNickname,
        phoneNumber: '+MAIL' + Date.now(),
        email: normalizedEmail,
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
        email: newUser.email,
        balance: newUser.balance,
      },
    });
  } catch (error: any) {
    console.error('REGISTER HATA:', error);
    res.status(500).json({ message: 'Server error', error: error.message || String(error) });
  }
};

export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, nickname, password, fcmToken } = req.body;

    if ((!email && !nickname) || !password) {
      res.status(400).json({ message: 'E-posta (veya kullanici adi) ve sifre zorunludur' });
      return;
    }

    let user: any;
    if (email) {
      user = await prisma.user.findUnique({ where: { email: String(email).trim().toLowerCase() } });
    } else {
      user = await (prisma as any).user.findFirst({
        where: { nickname: { equals: String(nickname).trim(), mode: 'insensitive' } }
      });
    }

    if (!user) {
      res.status(400).json({ message: 'Gecersiz e-posta/kullanici adi veya sifre' });
      return;
    }

    if ((user.role as string) === 'BANNED') {
      res.status(403).json({ message: 'Hesabiniz askiya alinmistir. Lutfen destek ile iletisime gecin.' });
      return;
    }

    const isMatch = await bcrypt.compare(String(password), user.passwordHash);
    if (!isMatch) {
      res.status(400).json({ message: 'Gecersiz e-posta/kullanici adi veya sifre' });
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
        email: user.email,
        role: user.role,
        balance: user.balance,
      },
    });
  } catch (error: any) {
    console.error('LOGIN HATA:', error);
    res.status(500).json({ message: 'Server error', error: error.message || String(error) });
  }
};

export const telegramAuth = async (req: Request, res: Response): Promise<void> => {
  try {
    const { tgId, firstName, lastName, username } = req.body;
    if (!tgId) {
      res.status(400).json({ message: 'Telegram ID zorunludur' });
      return;
    }

    let user: any = await (prisma as any).user.findFirst({ where: { telegramId: String(tgId) } });

    if (!user) {
      const salt = await bcrypt.genSalt(10);
      const passwordHash = await bcrypt.hash(String(tgId) + 'tg_secret', salt);
      const mockPhone = '+TG' + tgId;

      user = await (prisma as any).user.create({
        data: {
          firstName: String(firstName || 'Telegram'),
          lastName: lastName ? String(lastName) : '',
          nickname: username ? String(username) : await findUniqueNickname('tg' + tgId, 'tg'),
          phoneNumber: mockPhone,
          telegramId: String(tgId),
          passwordHash,
        }
      });
    }

    if (!user) {
      res.status(500).json({ message: 'Kullanici olusturulamadi.' });
      return;
    }
    if ((user.role as string) === 'BANNED') {
      res.status(403).json({ message: 'Hesabiniz askiya alinmistir.' });
      return;
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
    res.status(500).json({ message: 'Server error', error: error.message || String(error) });
  }
};

export const sendVerificationEmail = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email } = req.body;
    if (!email) {
      res.status(400).json({ message: 'E-posta zorunludur' });
      return;
    }

    const normalizedEmail = String(email).trim().toLowerCase();

    const existingUser = await prisma.user.findUnique({ where: { email: normalizedEmail } });
    if (existingUser) {
      res.status(400).json({ message: 'Bu e-posta zaten kayitli.' });
      return;
    }

    const code = Math.floor(1000 + Math.random() * 9000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60000);

    await (prisma as any).verificationCode.create({
      data: { email: normalizedEmail, code, expiresAt }
    });

    const RESEND_API_KEY = process.env.RESEND_API_KEY;
    const EMAIL_FROM = process.env.EMAIL_FROM || 'Hossarpay <noreply@hossarpay.com>';

    if (!RESEND_API_KEY) {
      console.log('[DEV MODE] Dogrulama kodu: ' + code + ' (e-posta: ' + normalizedEmail + ')');
      res.status(200).json({
        message: 'Dogrulama kodu gonderildi (DEV MODE).',
        devCode: code
      });
      return;
    }

    const html = '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">' +
      '<h2 style="color: #8B5CF6; text-align: center;">Hossarpay\'e Hos Geldiniz!</h2>' +
      '<p style="font-size: 16px; color: #333;">Hesabinizi dogrulamak icin asagidaki 4 haneli guvenlik kodunu kullanin:</p>' +
      '<div style="text-align: center; margin: 30px 0;">' +
      '<span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #8B5CF6; padding: 15px 30px; background-color: #f0f7ff; border-radius: 8px;">' + code + '</span>' +
      '</div>' +
      '<p style="font-size: 14px; color: #666;">Bu kod 10 dakika boyunca gecerlidir. Lutfen bu kodu kimseyle paylasmayin.</p>' +
      '<hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">' +
      '<p style="font-size: 12px; color: #999; text-align: center;">&copy; 2026 Hossarpay. Tum Haklari Saklidir.</p>' +
      '</div>';

    const resendResp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + RESEND_API_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: EMAIL_FROM,
        to: [normalizedEmail],
        subject: 'Hossarpay - Dogrulama Kodunuz',
        html: html
      })
    });

    if (!resendResp.ok) {
      const errText = await resendResp.text();
      console.error('Resend hatasi:', errText);
      res.status(500).json({ message: 'E-posta gonderilemedi', error: errText });
      return;
    }

    console.log('[EMAIL BASARIYLA GONDERILDI] Alici: ' + normalizedEmail);
    res.status(200).json({ message: 'Dogrulama kodu gonderildi.' });
  } catch (error: any) {
    console.error('EMAIL SEND ERROR:', error);
    res.status(500).json({ message: 'E-posta gonderilemedi', error: error.message || String(error) });
  }
};

export const googleAuth = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, firstName, lastName, photoUrl, googleId } = req.body;
    if (!email) {
      res.status(400).json({ message: 'E-Posta zorunludur' });
      return;
    }

    const normalizedEmail = String(email).trim().toLowerCase();

    let user: any = await (prisma as any).user.findUnique({ where: { email: normalizedEmail } });

    if (!user) {
      const salt = await bcrypt.genSalt(10);
      const passwordHash = await bcrypt.hash(normalizedEmail + 'google_secret', salt);
      const mockPhone = '+GL' + Date.now().toString().substring(0, 8);
      const newRefCode = generateReferralCode(String(firstName || 'Google'));

      user = await (prisma as any).user.create({
        data: {
          firstName: String(firstName || 'Google'),
          lastName: lastName ? String(lastName) : '',
          nickname: await findUniqueNickname(normalizedEmail, String(firstName || 'Google')),
          phoneNumber: mockPhone,
          email: normalizedEmail,
          isEmailVerified: true,
          profileImage: photoUrl ? String(photoUrl) : null,
          passwordHash,
          referralCode: newRefCode,
        }
      });
    }

    if ((user.role as string) === 'BANNED') {
      res.status(403).json({ message: 'Hesabiniz askiya alinmistir.' });
      return;
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
    res.status(500).json({ message: 'Server error', error: error.message || String(error) });
  }
};