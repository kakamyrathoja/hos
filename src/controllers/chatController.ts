import { Response } from 'express';
import { prisma } from '../index';
import { AuthRequest } from '../middlewares/authMiddleware';
import { sendNotification } from '../utils/firebase'; 

export const sendMessage = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const senderId = req.user?.id;
    const { receiverId, groupId, content, imageUrl, audioUrl, replyToId } = req.body;
    
    if (!senderId) { res.status(401).json({ message: 'Unauthorized' }); return; }
    if (!content && !imageUrl && !audioUrl) { res.status(400).json({ message: 'Mesaj boş olamaz' }); return; }

    if (groupId) {
      const isMember = await prisma.groupMember.findUnique({
        where: { userId_groupId: { userId: senderId, groupId: String(groupId) } }
      });
      if (!isMember) {
        res.status(403).json({ message: 'Bu gruba mesaj gönderme yetkiniz yok.' });
        return;
      }
    }

    const messageData: any = {
      senderId, 
      receiverId: receiverId ? String(receiverId) : null, 
      groupId: groupId ? String(groupId) : null, 
      content: content ? String(content) : null, 
      imageUrl: imageUrl ? String(imageUrl) : null,
      replyToId: replyToId ? String(replyToId) : null 
    };

    const message = await prisma.message.create({
      data: messageData,
      include: {
        sender: { select: { firstName: true, nickname: true, profileImage: true } }
      }
    });

    const senderName = message.sender.nickname || message.sender.firstName;
    const messageText = content ? String(content) : '📷 Bir fotoğraf gönderdi';

    if (receiverId) {
      const receiver = await prisma.user.findUnique({ where: { id: String(receiverId) }, select: { fcmToken: true } });
      if (receiver?.fcmToken) {
        sendNotification(receiver.fcmToken, senderName, messageText, { senderId }).catch(e => console.log('Bildirim hatası', e));
      }
    } 
    else if (groupId) {
      const group = await prisma.chatGroup.findUnique({
        where: { id: String(groupId) },
        include: { members: { include: { user: { select: { id: true, fcmToken: true } } } } }
      });
      if (group) {
        for (const member of group.members) {
          if (member.user.id !== senderId && member.user.fcmToken) {
            sendNotification(member.user.fcmToken, `${group.name} - ${senderName}`, messageText, { groupId: String(groupId) }).catch(e => console.log('Bildirim hatası', e));
          }
        }
      }
    }

    res.status(201).json(message);
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const getMessages = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { otherUserId, groupId } = req.query;
    if (!userId) { res.status(401).json({ message: 'Unauthorized' }); return; }

    let messages;
    if (groupId) {
      messages = await prisma.message.findMany({
        where: { groupId: String(groupId) },
        include: { sender: { select: { id: true, firstName: true, nickname: true, profileImage: true } } },
        orderBy: { createdAt: 'asc' }
      });
    } else if (otherUserId) {
      messages = await prisma.message.findMany({
        where: {
          OR: [
            { senderId: userId, receiverId: String(otherUserId) },
            { senderId: String(otherUserId), receiverId: userId }
          ]
        },
        include: { sender: { select: { id: true, firstName: true, nickname: true, profileImage: true } } },
        orderBy: { createdAt: 'asc' }
      });
      
      // isRead iptal edildi
      
    } else {
      res.status(400).json({ message: 'otherUserId or groupId is required' }); return;
    }

    res.status(200).json(messages);
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const editMessage = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { messageId } = req.params;
    const { content } = req.body;

    const message = await prisma.message.findUnique({ where: { id: String(messageId) } });
    if (!message) { res.status(404).json({ message: 'Mesaj bulunamadı' }); return; }
    if (message.senderId !== userId) { res.status(403).json({ message: 'Sadece kendi mesajınızı düzenleyebilirsiniz.' }); return; }

    const updateData: any = { content: String(content), isEdited: true };
    await prisma.message.update({
      where: { id: String(messageId) },
      data: updateData
    });

    res.status(200).json({ message: 'Mesaj düzenlendi' });
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const pinMessage = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { messageId } = req.params;
    
    const message: any = await prisma.message.findUnique({ where: { id: String(messageId) } });
    if (!message) { res.status(404).json({ message: 'Mesaj bulunamadı' }); return; }

    const pinData: any = { isPinned: !message.isPinned };
    await prisma.message.update({
      where: { id: String(messageId) },
      data: pinData
    });

    res.status(200).json({ message: 'Sabitleme durumu değiştirildi' });
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const deleteMessage = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { messageId } = req.params;

    const message = await prisma.message.findUnique({ where: { id: String(messageId) } });
    if (!message) { res.status(404).json({ message: 'Mesaj bulunamadı' }); return; }
    
    if (message.senderId !== userId) {
      res.status(403).json({ message: 'Sadece kendi mesajınızı silebilirsiniz.' }); return;
    }

    await prisma.message.delete({ where: { id: String(messageId) } });
    res.status(200).json({ message: 'Mesaj silindi' });
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const createGroup = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { name, isPrivate, groupImage, memberIds } = req.body; 
    if (!userId) { res.status(401).json({ message: 'Unauthorized' }); return; }

    const membersList = [userId, ...(memberIds || [])].map((id: string) => ({ userId: String(id) }));

    const groupData: any = {
      name: String(name),
      isPrivate: isPrivate === true,
      groupImage: groupImage ? String(groupImage) : null,
      creatorId: userId, 
      members: { create: membersList }
    };

    const group = await prisma.chatGroup.create({
      data: groupData,
      include: { members: { include: { user: { select: { id: true, firstName: true, nickname: true } } } } }
    });

    res.status(201).json(group);
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const getGroupDetails = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { groupId } = req.params;
    
    const group = await prisma.chatGroup.findUnique({ 
      where: { id: String(groupId) },
      include: { 
        members: { 
          include: { 
            user: { select: { id: true, firstName: true, lastName: true, nickname: true, phoneNumber: true, profileImage: true } } 
          } 
        } 
      }
    });

    if (!group) { res.status(404).json({ message: 'Grup bulunamadı' }); return; }
    res.status(200).json(group);
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const updateGroup = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    const { groupId } = req.params;
    const { name, groupImage } = req.body;

    const group = await prisma.chatGroup.findUnique({ where: { id: String(groupId) }});
    if (!group) { res.status(404).json({ message: 'Grup bulunamadı' }); return; }
    
    if (group.creatorId !== currentUserId) {
      res.status(403).json({ message: 'Sadece kurucu grup ayarlarını değiştirebilir.' }); return;
    }

    const dataToUpdate: any = {};
    if (name) dataToUpdate.name = String(name);
    if (groupImage !== undefined) dataToUpdate.groupImage = groupImage ? String(groupImage) : null;

    const updatedGroup = await prisma.chatGroup.update({
      where: { id: String(groupId) },
      data: dataToUpdate
    });

    res.status(200).json(updatedGroup);
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const leaveOrRemoveFromGroup = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    const { groupId, targetUserId } = req.body; 
    
    const group = await prisma.chatGroup.findUnique({ where: { id: String(groupId) }});
    if (!group) { res.status(404).json({ message: 'Grup bulunamadı' }); return; }

    if (targetUserId && String(targetUserId) !== currentUserId && group.creatorId !== currentUserId) {
      res.status(403).json({ message: 'Bunun için grup yöneticisi olmalısınız.' }); return;
    }

    const userToRemove = targetUserId ? String(targetUserId) : currentUserId;
    if (!userToRemove) return;

    await prisma.groupMember.delete({
      where: { userId_groupId: { groupId: String(groupId), userId: userToRemove } }
    });

    res.status(200).json({ message: 'Başarıyla gruptan ayrıldı/çıkarıldı.' });
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const addMembersToGroup = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    const { groupId, newMemberId } = req.body; 

    const group = await prisma.chatGroup.findUnique({ where: { id: String(groupId) }});
    if (!group) { res.status(404).json({ message: 'Grup bulunamadı' }); return; }
    if (group.creatorId !== currentUserId) {
      res.status(403).json({ message: 'Sadece grup yöneticisi kişi ekleyebilir.' }); return;
    }

    await prisma.groupMember.create({ data: { userId: String(newMemberId), groupId: String(groupId) } });

    res.status(200).json({ message: 'Kişi gruba eklendi.' });
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const deleteGroup = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    const { groupId } = req.params;

    const group = await prisma.chatGroup.findUnique({ where: { id: String(groupId) }});
    if (!group) { res.status(404).json({ message: 'Grup bulunamadı' }); return; }
    if (group.creatorId !== currentUserId) {
      res.status(403).json({ message: 'Sadece kurucu grubu tamamen silebilir.' }); return;
    }

    await prisma.chatGroup.delete({ where: { id: String(groupId) }});
    res.status(200).json({ message: 'Grup tamamen silindi.' });
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

// YENİ: KESİN VE GARANTİLİ SOHBET LİSTELEME ALGORİTMASI (Hata Fırlatmayan Versiyon)
export const getConversations = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    if (!userId) { res.status(401).json({ message: 'Unauthorized' }); return; }

    const sent = await prisma.message.findMany({ 
      where: { senderId: userId, receiverId: { not: null } }, 
      include: { receiver: { select: { id: true, firstName: true, nickname: true, profileImage: true } } }
    });
    
    const received = await prisma.message.findMany({ 
      where: { receiverId: userId }, 
      include: { sender: { select: { id: true, firstName: true, nickname: true, profileImage: true } } }
    });

    const groups = await prisma.groupMember.findMany({ 
      where: { userId }, 
      include: { 
        group: {
          include: {
            messages: { orderBy: { createdAt: 'desc' }, take: 1 } 
          }
        }
      } 
    });

    // isRead sütunu veritabanında olmadığı için çökmesini engelledik.
    const unreadMap: { [key: string]: number } = {};

    // Basit ve güvenli bir JSON objesi ile kişileri eşleştiriyoruz
    const conversationMap: { [key: string]: any } = {};

    for (const m of sent) {
      if (m.receiver && m.receiver.id) {
        if (!conversationMap[m.receiver.id]) {
          conversationMap[m.receiver.id] = { 
            isGroup: false, id: m.receiver.id, name: m.receiver.nickname || m.receiver.firstName, 
            image: m.receiver.profileImage, isCreator: false, 
            lastMessage: m.content || (m.imageUrl ? '📷 Fotoğraf' : ((m as any).audioUrl ? '🎤 Sesli Mesaj' : '')), 
            lastMessageDate: m.createdAt,
            unreadCount: unreadMap[(m as any).receiver?.id] || 0
          };
        } else {
          if (new Date(m.createdAt) > new Date(conversationMap[m.receiver.id].lastMessageDate)) {
            conversationMap[m.receiver.id].lastMessageDate = m.createdAt;
            conversationMap[m.receiver.id].lastMessage = m.content || (m.imageUrl ? '📷 Fotoğraf' : '');
          }
        }
      }
    }

    for (const m of received) {
      if (m.sender && m.sender.id) {
        if (!conversationMap[m.sender.id]) {
          conversationMap[m.sender.id] = { 
            isGroup: false, id: m.sender.id, name: m.sender.nickname || m.sender.firstName, 
            image: m.sender.profileImage, isCreator: false, 
            lastMessage: m.content || (m.imageUrl ? '📷 Fotoğraf' : ((m as any).audioUrl ? '🎤 Sesli Mesaj' : '')), 
            lastMessageDate: m.createdAt,
            unreadCount: unreadMap[(m as any).receiver?.id] || 0
          };
        } else {
          if (new Date(m.createdAt) > new Date(conversationMap[m.sender.id].lastMessageDate)) {
            conversationMap[m.sender.id].lastMessageDate = m.createdAt;
            conversationMap[m.sender.id].lastMessage = m.content || (m.imageUrl ? '📷 Fotoğraf' : '');
          }
        }
      }
    }

    for (const g of groups) {
      if (g.group && g.group.id) {
        const lastMsgDate = g.group.messages && g.group.messages.length > 0 ? g.group.messages[0].createdAt : g.group.createdAt;
        const lastMsgText = g.group.messages && g.group.messages.length > 0 ? (g.group.messages[0].content || '📷 Fotoğraf') : 'Grup oluşturuldu';
        
        conversationMap[g.group.id] = { 
          isGroup: true, id: g.group.id, name: g.group.name, image: g.group.groupImage, 
          isCreator: g.group.creatorId === userId, 
          lastMessage: lastMsgText,
          lastMessageDate: lastMsgDate 
        };
      }
    }

    // Listeye çevirip tarihe göre sırala
    const conversations = Object.values(conversationMap);
    conversations.sort((a, b) => new Date(b.lastMessageDate).getTime() - new Date(a.lastMessageDate).getTime());

    res.status(200).json(conversations);
  } catch (error) { 
    console.error("GET CONVERSATIONS ERROR:", error);
    res.status(500).json({ message: 'Server error', error }); 
  }
};

export const getAdminContact = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    // 1. Öncelik: Uygulamada "Destek" takma adına (nickname) sahip bir ADMIN var mı diye bak.
    // Senin 3 adminden hangisinin mesajları karşılamasını istiyorsan uygulamanın içinden onun 
    // profiline girip Takma Adını "ADMIN" yap.
    let admin = await prisma.user.findFirst({
      where: { role: 'ADMIN', nickname: { equals: 'ADMIN', mode: 'insensitive' } },
      select: { id: true, nickname: true, firstName: true }
    });

    // 2. Eğer "ADMIN" lakaplı biri yoksa, eski sistemdeki gibi rastgele bir Admini getir.
    if (!admin) {
      admin = await prisma.user.findFirst({
        where: { role: 'ADMIN' },
        select: { id: true, nickname: true, firstName: true }
      });
    }

    res.status(200).json(admin);
  } catch (error) { res.status(500).json({ message: 'Server error', error }); }
};

export const clearHistory = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const { otherUserId } = req.params;

    if (!userId || !otherUserId) {
      res.status(400).json({ message: 'Eksik parametre' });
      return;
    }

    await prisma.message.deleteMany({
      where: {
        OR: [
          { senderId: userId, receiverId: String(otherUserId) },
          { senderId: String(otherUserId), receiverId: userId }
        ]
      }
    });

    res.status(200).json({ message: 'Sohbet geçmişi temizlendi' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error });
  }
};