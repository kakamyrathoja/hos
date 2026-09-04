import { Response } from 'express';
import { prisma } from '../index';
import { AuthRequest } from '../middlewares/authMiddleware';
import { sendNotification } from '../utils/firebase'; // YENİ EKLENDİ

export const transferTMT = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const senderId = req.user?.id;
    const { receiverId, amount } = req.body; 

    if (!senderId) {
      res.status(401).json({ message: 'Unauthorized' });
      return;
    }

    const transferAmount = parseFloat(amount);
    if (isNaN(transferAmount) || transferAmount <= 0) {
      res.status(400).json({ message: 'Geçersiz transfer tutarı.' });
      return;
    }

    const result = await prisma.$transaction(async (tx) => {
      const sender = await tx.user.findUnique({ where: { id: senderId } });
      if (!sender) throw new Error('Gönderici bulunamadı.');
      if (Number(sender.balance) < transferAmount) throw new Error('Yetersiz bakiye.');

      const receiver = await tx.user.findUnique({ where: { id: receiverId } });
      if (!receiver) throw new Error('Alıcı bulunamadı.');
      if (sender.id === receiver.id) throw new Error('Kendinize transfer yapamazsınız.');

      const updatedSender = await tx.user.update({
        where: { id: senderId },
        data: { balance: { decrement: transferAmount } },
      });

      await tx.user.update({
        where: { id: receiver.id },
        data: { balance: { increment: transferAmount } },
      });

      const transactionRecord = await tx.transaction.create({
        data: {
          senderId,
          receiverId: receiver.id,
          amount: transferAmount,
          status: 'COMPLETED',
        },
      });

      // BİLDİRİM: Alıcıya para geldiğinin bildirimini atıyoruz
      if (receiver.fcmToken) {
        const senderName = sender.nickname || sender.firstName;
        await sendNotification(receiver.fcmToken, 'Yeni Transfer!', `${senderName} size ${transferAmount} TMT gönderdi.`);
      }

      return { transactionRecord, newBalance: updatedSender.balance };
    });

    res.status(200).json({
      message: 'Transfer başarılı!',
      transaction: result.transactionRecord,
      newBalance: result.newBalance,
    });

  } catch (error: any) {
    if (error.message === 'Yetersiz bakiye.' || error.message === 'Alıcı bulunamadı.' || error.message === 'Kendinize transfer yapamazsınız.') {
      res.status(400).json({ message: error.message });
    } else {
      res.status(500).json({ message: 'Sunucu hatası veya işlem başarısız oldu.', error: error.message });
    }
  }
};