import { Response } from 'express';
import { prisma } from '../index';
import { AuthRequest } from '../middlewares/authMiddleware';
import { sendNotification } from '../utils/firebase';

// Şikayet eşiği: bu kadar şikayet gelince içerik otomatik gizlenir
const REPORT_THRESHOLD = 3;

const VALID_REASONS = ['SPAM', 'ABUSE', 'HARASSMENT', 'OTHER'];

function isBlockedPair(blockerId: string, blockedId: string): boolean {
  return blockerId === blockedId;
}

// ============================================================
// KULLANICI: Şikayet Et
// POST /report  { targetType: 'USER'|'MESSAGE'|'STORY', targetId, reason }
// ============================================================
export const createReport = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const reporterId = req.user?.id;
    const { targetType, targetId, reason } = req.body;
    if (!reporterId) { res.status(401).json({ message: 'Unauthorized' }); return; }

    const type = String(targetType || '').toUpperCase();
    if (!['USER', 'MESSAGE', 'STORY'].includes(type)) {
      res.status(400).json({ message: 'Geçersiz şikayet türü.' }); return;
    }
    if (!targetId) { res.status(400).json({ message: 'Şikayet hedefi eksik.' }); return; }
    const reasonText = String(reason || 'OTHER').toUpperCase();
    const reasonKey = VALID_REASONS.includes(reasonText) ? reasonText : 'OTHER';

    // Hedef gerçekten var mı?
    let exists = false;
    if (type === 'MESSAGE') {
      exists = !!(await prisma.message.findUnique({ where: { id: String(targetId) }, select: { id: true } }));
    } else if (type === 'STORY') {
      exists = !!(await prisma.story.findUnique({ where: { id: String(targetId) }, select: { id: true } }));
    } else {
      exists = !!(await prisma.user.findUnique({ where: { id: String(targetId) }, select: { id: true } }));
      if (String(targetId) === reporterId) {
        res.status(400).json({ message: 'Kendinizi şikayet edemezsiniz.' }); return;
      }
    }
    if (!exists) { res.status(404).json({ message: 'Şikayet edilen içerik bulunamadı.' }); return; }

    // Aynı kullanıcı aynı hedefi 2 kez şikayet edemez (unique constraint)
    const report = await prisma.report.upsert({
      where: {
        reporterId_targetType_targetId: {
          reporterId,
          targetType: type as any,
          targetId: String(targetId),
        },
      },
      update: { reason: reasonKey, status: 'PENDING' },
      create: {
        reporterId,
        targetType: type as any,
        targetId: String(targetId),
        reason: reasonKey,
      },
    });

    // 3+ şikayet → içeriği otomatik gizle
    let autoHidden = false;
    if (type === 'MESSAGE') {
      const total = await prisma.report.count({ where: { targetType: 'MESSAGE', targetId: String(targetId) } });
      if (total >= REPORT_THRESHOLD) {
        await prisma.message.update({ where: { id: String(targetId) }, data: { reportCount: total, isHidden: true } });
        autoHidden = true;
      } else {
        await prisma.message.update({ where: { id: String(targetId) }, data: { reportCount: total } });
      }
    } else if (type === 'STORY') {
      const total = await prisma.report.count({ where: { targetType: 'STORY', targetId: String(targetId) } });
      if (total >= REPORT_THRESHOLD) {
        await prisma.story.update({ where: { id: String(targetId) }, data: { reportCount: total, isHidden: true } });
        autoHidden = true;
      } else {
        await prisma.story.update({ where: { id: String(targetId) }, data: { reportCount: total } });
      }
    }

    res.status(201).json({ message: 'Şikayetiniz alındı.', autoHidden, report });
  } catch (error: any) {
    console.error('CREATE REPORT ERROR:', error);
    res.status(500).json({ message: 'Report error', details: error.message || error });
  }
};

// ============================================================
// KULLANICI: Kullanıcıyı Engelle
// POST /block  { blockedUserId }
// ============================================================
export const blockUser = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const blockerId = req.user?.id;
    const { blockedUserId } = req.body;
    if (!blockerId) { res.status(401).json({ message: 'Unauthorized' }); return; }
    if (!blockedUserId) { res.status(400).json({ message: 'Engellenecek kullanıcı eksik.' }); return; }
    if (isBlockedPair(blockerId, String(blockedUserId))) {
      res.status(400).json({ message: 'Kendinizi engelleyemezsiniz.' }); return;
    }

    const target = await prisma.user.findUnique({ where: { id: String(blockedUserId) }, select: { id: true } });
    if (!target) { res.status(404).json({ message: 'Kullanıcı bulunamadı.' }); return; }

    const block = await prisma.block.upsert({
      where: { blockerId_blockedId: { blockerId, blockedId: String(blockedUserId) } },
      update: {},
      create: { blockerId, blockedId: String(blockedUserId) },
    });

    res.status(201).json({ message: 'Kullanıcı engellendi.', block });
  } catch (error: any) {
    console.error('BLOCK USER ERROR:', error);
    res.status(500).json({ message: 'Block error', details: error.message || error });
  }
};

// ============================================================
// KULLANICI: Engeli Kaldır
// DELETE /block/:blockedUserId
// ============================================================
export const unblockUser = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const blockerId = req.user?.id;
    const { blockedUserId } = req.params;
    if (!blockerId) { res.status(401).json({ message: 'Unauthorized' }); return; }

    await prisma.block.deleteMany({
      where: { blockerId, blockedId: String(blockedUserId) },
    });

    res.status(200).json({ message: 'Engel kaldırıldı.' });
  } catch (error: any) {
    console.error('UNBLOCK USER ERROR:', error);
    res.status(500).json({ message: 'Unblock error', details: error.message || error });
  }
};

// ============================================================
// KULLANICI: Engellediğim kullanıcılar
// GET /blocks
// ============================================================
export const getBlocks = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    if (!userId) { res.status(401).json({ message: 'Unauthorized' }); return; }

    const blocks = await prisma.block.findMany({
      where: { blockerId: userId },
      include: { blocked: { select: { id: true, firstName: true, nickname: true, profileImage: true } } },
      orderBy: { createdAt: 'desc' },
    });

    res.status(200).json(blocks);
  } catch (error: any) {
    console.error('GET BLOCKS ERROR:', error);
    res.status(500).json({ message: 'Blocks error', details: error.message || error });
  }
};

// ============================================================
// ADMIN: Bekleyen şikayetler
// GET /admin/reports?status=PENDING
// ============================================================
export const getReports = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const status = String(req.query.status || 'PENDING').toUpperCase();
    const reports = await prisma.report.findMany({
      where: { status: status as any },
      include: {
        reporter: { select: { id: true, firstName: true, nickname: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });

    // Her şikayetin hedef içeriğini de ekle (admin inceleyebilsin)
    const enriched = await Promise.all(reports.map(async (r) => {
      let target: any = null;
      if (r.targetType === 'MESSAGE') {
        const m = await prisma.message.findUnique({
          where: { id: r.targetId },
          include: { sender: { select: { id: true, firstName: true, nickname: true, phoneNumber: true } } },
        });
        target = m ? { id: m.id, content: m.content, imageUrl: m.imageUrl, sender: m.sender, reportCount: m.reportCount, isHidden: m.isHidden } : null;
      } else if (r.targetType === 'STORY') {
        const s = await prisma.story.findUnique({
          where: { id: r.targetId },
          include: { user: { select: { id: true, firstName: true, nickname: true, phoneNumber: true } } },
        });
        target = s ? { id: s.id, mediaUrl: s.mediaUrl, user: s.user, reportCount: s.reportCount, isHidden: s.isHidden } : null;
      } else {
        const u = await prisma.user.findUnique({
          where: { id: r.targetId },
          select: { id: true, firstName: true, nickname: true, phoneNumber: true, role: true },
        });
        target = u;
      }
      return { ...r, target };
    }));

    res.status(200).json(enriched);
  } catch (error: any) {
    console.error('GET REPORTS ERROR:', error);
    res.status(500).json({ message: 'Get reports error', details: error.message || error });
  }
};

// ============================================================
// ADMIN: Şikayeti işle
// PUT /admin/reports/:id  { action: 'REMOVED' | 'KEPT' }
// ============================================================
export const resolveReport = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { action } = req.body;
    if (!['REMOVED', 'KEPT'].includes(String(action))) {
      res.status(400).json({ message: 'Geçersiz işlem.' }); return;
    }

    const report = await prisma.report.findUnique({ where: { id: String(id) } });
    if (!report) { res.status(404).json({ message: 'Şikayet bulunamadı.' }); return; }
    if (report.status !== 'PENDING') {
      res.status(400).json({ message: 'Bu şikayet zaten işlenmiş.' }); return;
    }

    const relatedReports = await prisma.report.findMany({
      where: { targetType: report.targetType, targetId: report.targetId, status: 'PENDING' },
    });

    const ownerId = report.targetType === 'MESSAGE'
      ? (await prisma.message.findUnique({ where: { id: report.targetId }, select: { senderId: true } }))?.senderId
      : report.targetType === 'STORY'
        ? (await prisma.story.findUnique({ where: { id: report.targetId }, select: { userId: true } }))?.userId
        : null;

    await prisma.$transaction(async (tx) => {
      if (String(action) === 'REMOVED') {
        if (report.targetType === 'MESSAGE') {
          await tx.message.deleteMany({ where: { id: report.targetId } });
        } else if (report.targetType === 'STORY') {
          await tx.story.deleteMany({ where: { id: report.targetId } });
        } else {
          await tx.user.update({
            where: { id: report.targetId },
            data: { role: 'BANNED' },
          });
        }
        await tx.report.updateMany({
          where: { id: { in: relatedReports.map((r) => r.id) } },
          data: { status: 'REMOVED' },
        });

        if (ownerId) {
          const ownerUser = await prisma.user.findUnique({
            where: { id: ownerId },
            select: { fcmToken: true },
          });
          if (ownerUser?.fcmToken) {
            sendNotification(ownerUser.fcmToken, 'Hossarpay', 'İçeriğiniz şikayet üzerine kaldırıldı.').catch(() => {});
          }
        }
      } else {
        if (report.targetType === 'MESSAGE') {
          await tx.message.updateMany({ where: { id: report.targetId }, data: { isHidden: false, reportCount: 0 } });
        } else if (report.targetType === 'STORY') {
          await tx.story.updateMany({ where: { id: report.targetId }, data: { isHidden: false, reportCount: 0 } });
        }
        await tx.report.updateMany({
          where: { id: { in: relatedReports.map((r) => r.id) } },
          data: { status: 'KEPT' },
        });
      }
    });

    res.status(200).json({ message: 'Şikayet işlendi.' });
  } catch (error: any) {
    console.error('RESOLVE REPORT ERROR:', error);
    res.status(500).json({ message: 'Resolve report error', details: error.message || error });
  }
};