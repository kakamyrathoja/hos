import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { prisma } from '../index';

const JWT_SECRET = process.env.JWT_SECRET || 'secret';

export interface AuthRequest extends Request {
  user?: {
    id: string;
    role: string;
  };
}

export const authenticate = (req: AuthRequest, res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ message: 'Unauthorized: No token provided' });
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { id: string; role: string };
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ message: 'Unauthorized: Invalid token' });
  }
};

// YENİ (düzeltme): Rolü JWT'den değil, VERİTABANINDAN oku.
// Böylece hesap ADMIN yapıldıktan sonra eski token'la bile admin paneli açılır.
export const authorizeAdmin = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    if (!req.user?.id) {
      res.status(401).json({ message: 'Unauthorized' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { id: true, role: true },
    });

    if (user && user.role === 'ADMIN') {
      // req.user.role'u da güncelle (sonraki kullanımlar için)
      req.user.role = user.role;
      next();
    } else {
      res.status(403).json({ message: 'Forbidden: Admin access required' });
    }
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
};
