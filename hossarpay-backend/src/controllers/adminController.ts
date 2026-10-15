import { Response } from 'express';
import { prisma } from '../index';
import { AuthRequest } from '../middlewares/authMiddleware';
import { sendNotification } from '../utils/firebase'; 

export const getAllUsers = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { search } = req.query; 
    const whereClause = search ? {
      OR: [
        { firstName: { contains: String(search), mode: 'insensitive' as const } },
        { phoneNumber: { contains: String(search) } },
        { nickname: { contains: String(search), mode: 'insensitive' as const } }
      ]
    } : {};

    const users = await prisma.user.findMany({
      where: whereClause,
      select: {
        id: true, firstName: true, lastName: true, nickname: true, phoneNumber: true, balance: true, role: true, createdAt: true
      },
      orderBy: { createdAt: 'desc' }
    });
    res.status(200).json(users);
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const updateUserBalance = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { userId, newBalance } = req.body;
    if (newBalance === undefined || newBalance < 0) { res.status(400).json({ message: 'Valid new balance is required' }); return; }

    const updatedUser = await prisma.user.update({
      where: { id: String(userId) },
      data: { balance: newBalance },
      select: { id: true, firstName: true, phoneNumber: true, balance: true, fcmToken: true }
    });

    res.status(200).json({ message: 'Balance updated successfully', user: updatedUser });
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const getPendingPurchases = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const purchases = await prisma.purchase.findMany({
      where: { status: 'PENDING' },
      include: {
        user: { select: { firstName: true, lastName: true, phoneNumber: true, nickname: true } },
        service: { select: { name: true } }
      },
      orderBy: { createdAt: 'desc' }
    });
    res.status(200).json(purchases);
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const resolvePurchase = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { purchaseId, action } = req.body;
    const adminId = req.user?.id; 

    if (!['COMPLETED', 'FAILED'].includes(String(action))) {
      res.status(400).json({ message: 'Invalid action.' }); return;
    }

    const result = await prisma.$transaction(async (tx) => {
      const purchase = await tx.purchase.findUnique({ 
        where: { id: String(purchaseId) },
        include: { user: { select: { id: true, fcmToken: true } }, service: { select: { name: true } } }
      });
      if (!purchase) throw new Error('Purchase not found');
      if (purchase.status !== 'PENDING') throw new Error('Purchase is already resolved');

      if (String(action) === 'FAILED') {
        await tx.user.update({
          where: { id: purchase.userId },
          data: { balance: { increment: purchase.amount } }
        });
      }

      const updatedPurchase = await tx.purchase.update({
        where: { id: String(purchaseId) },
        data: { status: action, resolvedById: adminId } 
      });

      return updatedPurchase;
    });

    res.status(200).json({ message: `Purchase marked as ${action}`, purchase: result });
  } catch (error: any) { res.status(500).json({ message: 'Server error', error: error.message }); }
};

export const getSystemLogs = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { search } = req.query; // YENİ: ARAMA FİLTRESİ
    const qString = search ? String(search).toLowerCase() : '';

    // TÜM İŞLEMLERİ ÇEK (Eğer veri çoksa Take miktarını azaltabiliriz)
    const transactions = await prisma.transaction.findMany({
      include: {
        sender: { select: { firstName: true, phoneNumber: true, nickname: true } },
        receiver: { select: { firstName: true, phoneNumber: true, nickname: true } }
      },
      orderBy: { createdAt: 'desc' },
      take: 500 
    });

    let purchases: any[] = [];
    try {
      // Eğer veritabanında henüz resolvedBy (Admin) sütunu açılmadıysa diye güvenli çekim yapıyoruz
      purchases = await prisma.purchase.findMany({
        include: {
          user: { select: { firstName: true, phoneNumber: true, nickname: true } },
          service: { select: { name: true } },
          resolvedBy: { select: { firstName: true, nickname: true } } 
        },
        orderBy: { createdAt: 'desc' },
        take: 500
      });
    } catch (e) {
      // Sütun yoksa resolvedBy olmadan çek
      purchases = await prisma.purchase.findMany({
        include: {
          user: { select: { firstName: true, phoneNumber: true, nickname: true } },
          service: { select: { name: true } }
        },
        orderBy: { createdAt: 'desc' },
        take: 500
      });
    }

    let finalTransactions = transactions;
    let finalPurchases = purchases;

    // EĞER ARAMA (SEARCH) KUTUSU DOLUYSA BACKEND'DE FİLTRELEME YAP (KASMAYI ENGELLER)
    if (qString) {
      finalTransactions = transactions.filter(t => 
        (t.sender.firstName?.toLowerCase().includes(qString)) ||
        (t.sender.nickname?.toLowerCase().includes(qString)) ||
        (t.sender.phoneNumber?.includes(qString)) ||
        (t.receiver.firstName?.toLowerCase().includes(qString)) ||
        (t.receiver.nickname?.toLowerCase().includes(qString)) ||
        (t.receiver.phoneNumber?.includes(qString)) ||
        (t.status.toLowerCase().includes(qString))
      );

      finalPurchases = purchases.filter(p => 
        (p.user.firstName?.toLowerCase().includes(qString)) ||
        (p.user.nickname?.toLowerCase().includes(qString)) ||
        (p.user.phoneNumber?.includes(qString)) ||
        (p.targetAccount?.includes(qString)) ||
        (p.service.name?.toLowerCase().includes(qString)) ||
        (p.status.toLowerCase().includes(qString)) ||
        (p.resolvedBy?.firstName?.toLowerCase().includes(qString)) ||
        (p.resolvedBy?.nickname?.toLowerCase().includes(qString))
      );
    }

    res.status(200).json({ transactions: finalTransactions, purchases: finalPurchases });
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};