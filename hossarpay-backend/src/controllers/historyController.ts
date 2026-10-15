import { Response } from 'express';
import { prisma } from '../index';
import { AuthRequest } from '../middlewares/authMiddleware';

export const getMyTransfers = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const transfers = await prisma.transaction.findMany({
      where: {
        OR: [
          { senderId: userId },
          { receiverId: userId }
        ]
      },
      include: {
        sender: { select: { firstName: true, nickname: true, phoneNumber: true, profileImage: true } },
        receiver: { select: { firstName: true, nickname: true, phoneNumber: true, profileImage: true } }
      },
      orderBy: { createdAt: 'desc' }
    });
    
    // Kullanıcının anlayabileceği bir formata çevir (Ben gönderdim / Ben aldım)
    const formatted = transfers.map(t => ({
      id: t.id,
      amount: t.amount,
      status: t.status,
      date: t.createdAt,
      type: t.senderId === userId ? 'SENT' : 'RECEIVED',
      party: t.senderId === userId ? t.receiver : t.sender
    }));

    res.status(200).json(formatted);
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const getMyPurchases = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const purchases = await prisma.purchase.findMany({
      where: { userId },
      include: {
        service: { select: { name: true } },
        resolvedBy: { select: { nickname: true, firstName: true } } // Fişte admin onayı gösterebilmek için
      },
      orderBy: { createdAt: 'desc' }
    });

    res.status(200).json(purchases);
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};
