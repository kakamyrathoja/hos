import { Response } from 'express';
import { prisma } from '../index';
import { AuthRequest } from '../middlewares/authMiddleware';
import { sendNotification } from '../utils/firebase';
import { moderateImageBase64 } from '../utils/imageModeration';

export const createStory = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { mediaUrl } = req.body;
    if (!userId) { res.status(401).json({ message: 'Unauthorized' }); return; }
    
    // YENİ (FAZ B): Görsel denetim — yüklenmeden önce
    if (mediaUrl) {
      const moderation = await moderateImageBase64(String(mediaUrl));
      if (!moderation.approved) {
        res.status(400).json({ message: 'İçerik kurallarımıza uymuyor. Lütfen başka bir görsel deneyin.' });
        return;
      }
    }
    
    const oneDayAgo = new Date();
    oneDayAgo.setHours(oneDayAgo.getHours() - 24);

    const existingStory = await prisma.story.findFirst({
      where: { userId: userId, createdAt: { gt: oneDayAgo } }
    });
    if (existingStory) { res.status(400).json({ message: '24 saat içinde sadece 1 hikaye paylaşabilirsiniz.' }); return; }

    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24);

    const story = await prisma.story.create({ data: { userId, mediaUrl: String(mediaUrl), expiresAt } });
    res.status(201).json({ message: 'Story paylaşıldı', story });
  } catch (error: any) { 
    console.error("CREATE STORY ERROR:", error);
    res.status(500).json({ message: 'Create story error', details: error.message || error }); 
  }
};

export const getActiveStories = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    if (!userId) return;

        // YENİ: Engellenen kullanıcıların hikayelerini gizle (iki yönlü)
    const blocks = await prisma.block.findMany({
      where: { OR: [{ blockerId: userId }, { blockedId: userId }] },
      select: { blockerId: true, blockedId: true },
    });
    const blockedUserIds = new Set<string>();
    for (const b of blocks) {
      if (b.blockerId === userId) blockedUserIds.add(b.blockedId);
      if (b.blockedId === userId) blockedUserIds.add(b.blockerId);
    }

    // Kullanıcının paylaştığı hikaye sohbetindeki HERKESE görünür olması için
    // Artık herhangi bir "rehber" kısıtlaması yapmıyoruz. 
    // Süresi dolmamış TÜM HİKAYELERİ getiriyoruz (Tıpkı global bir Super App gibi).
    const stories = await prisma.story.findMany({
        where: { 
        expiresAt: { gt: new Date() },
        isHidden: false,
        user: { id: { notIn: Array.from(blockedUserIds) } }
      },
      include: {
        user: { select: { id: true, firstName: true, nickname: true, profileImage: true } },
        views: { select: { user: { select: { id: true, nickname: true, firstName: true, profileImage: true } } } },
        reactions: { select: { emoji: true, user: { select: { id: true, nickname: true, firstName: true } } } }
      },
      orderBy: { createdAt: 'desc' }
    });

    const groupedStories = stories.reduce((acc: any, story) => {
      const uId = story.userId;
      if (!acc[uId]) acc[uId] = { user: story.user, stories: [] };
      acc[uId].stories.push(story);
      return acc;
    }, {});

    res.status(200).json(Object.values(groupedStories));
  } catch (error: any) { 
    console.error("GET STORIES ERROR:", error);
    res.status(500).json({ message: 'Get stories error', details: error.message || error }); 
  }
};

export const deleteStory = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { storyId } = req.params;

    const story = await prisma.story.findUnique({ where: { id: String(storyId) } });
    if (!story) { res.status(404).json({ message: 'Hikaye bulunamadı.' }); return; }
    if (story.userId !== userId) { res.status(403).json({ message: 'Sadece kendi hikayenizi silebilirsiniz.' }); return; }

    await prisma.story.delete({ where: { id: String(storyId) } });
    res.status(200).json({ message: 'Hikaye başarıyla silindi.' });
  } catch (error: any) { 
    console.error("DELETE STORY ERROR:", error);
    res.status(500).json({ message: 'Delete story error', details: error.message || error }); 
  }
};

export const viewStory = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { storyId } = req.body;
    if (!userId) return;

    await (prisma as any)['storyView'].upsert({
      where: { storyId_userId: { storyId: String(storyId), userId } },
      update: {},
      create: { storyId: String(storyId), userId }
    });
    res.status(200).json({ success: true });
  } catch (error: any) { 
    console.error("VIEW STORY ERROR:", error);
    res.status(500).json({ message: 'View story error', details: error.message || error }); 
  }
};

export const reactToStory = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id; 
    const { storyId, emoji } = req.body;
    if (!userId) return;

    const story = await prisma.story.findUnique({ 
      where: { id: String(storyId) },
      include: { user: { select: { id: true, fcmToken: true } } }
    });

    if (!story) { res.status(404).json({ message: 'Hikaye bulunamadı' }); return; }
    
    // YENİ: Engelleme kontrolü
    const blocked = await prisma.block.findFirst({
      where: {
        OR: [
          { blockerId: userId, blockedId: story.user.id },
          { blockerId: story.user.id, blockedId: userId },
        ],
      },
    });
    if (blocked) { res.status(403).json({ message: 'Bu kullanıcıyla etkileşim kuramazsınız.' }); return; }

    const reaction = await (prisma as any)['storyReaction'].create({
      data: { storyId: String(storyId), userId, emoji: String(emoji) }
    });

    const sender = await prisma.user.findUnique({ where: { id: userId } });
    const senderName = sender?.nickname || sender?.firstName || 'Biri';
    
    await prisma.message.create({
      data: {
        senderId: userId,
        receiverId: story.user.id,
        content: `Hikayenize yanıt verdi: ${emoji}`,
        imageUrl: story.mediaUrl 
      }
    });

    if (story.user.fcmToken) {
      sendNotification(
        story.user.fcmToken, 
        senderName, 
        `Hikayenize yanıt verdi: ${emoji}`
      ).catch(e => console.log('Story bildirim hatası', e));
    }

    res.status(200).json(reaction);
  } catch (error: any) { 
    console.error("REACT STORY ERROR:", error);
    res.status(500).json({ message: 'React story error', details: error.message || error }); 
  }
};