import { Response } from 'express';
import { prisma } from '../index';
import { AuthRequest } from '../middlewares/authMiddleware';
import { sendNotification } from '../utils/firebase'; 

export const getServices = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const services = await prisma.service.findMany({
      where: { isActive: true }
    });
    res.status(200).json(services);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error });
  }
};

export const purchaseService = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { serviceId, targetAccount, amount } = req.body;

    if (!userId) {
      res.status(401).json({ message: 'Unauthorized' }); return;
    }

    const purchaseAmount = parseFloat(amount);
    if (isNaN(purchaseAmount) || purchaseAmount <= 0) {
      res.status(400).json({ message: 'Invalid amount' }); return;
    }

    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) throw new Error('User not found');
      if (Number(user.balance) < purchaseAmount) throw new Error('Yetersiz bakiye');

      const service = await tx.service.findUnique({ where: { id: String(serviceId) } });
      if (!service) throw new Error('Service not found');

      const updatedUser = await tx.user.update({
        where: { id: userId },
        data: { balance: { decrement: purchaseAmount } }
      });

      const purchase = await tx.purchase.create({
        data: {
          userId,
          serviceId: String(serviceId),
          targetAccount: String(targetAccount), 
          amount: purchaseAmount,
          status: 'PENDING'
        }
      });

      return { purchase, serviceName: service.name, userName: user.nickname || user.firstName, newBalance: updatedUser.balance };
    });

    const admins = await prisma.user.findMany({ where: { role: 'ADMIN', fcmToken: { not: null } } });
    for (const admin of admins) {
      if (admin.fcmToken) {
        await sendNotification(admin.fcmToken, 'Yeni Hizmet Talebi!', `${result.userName}, ${result.serviceName} için ${purchaseAmount} TMT ödeme yaptı. Onayınızı bekliyor.`);
      }
    }

    res.status(200).json({
      message: 'Service purchase requested. Waiting for admin approval.',
      purchase: result.purchase,
      newBalance: result.newBalance
    });

  } catch (error: any) {
    if (error.message === 'Yetersiz bakiye') {
      res.status(400).json({ message: error.message });
    } else {
      res.status(500).json({ message: 'Server error', error: error.message });
    }
  }
};
