import { Router } from 'express';
import { register, login, telegramAuth, sendVerificationEmail, googleAuth } from '../controllers/authController';
import { 
  createReport, blockUser, unblockUser, getBlocks, getReports, resolveReport 
} from '../controllers/reportController';
import { getProfile, searchUser, updateProfile, syncContacts, secureAccount, getContacts } from '../controllers/userController';
import { transferTMT } from '../controllers/transactionController';
import { getServices, purchaseService } from '../controllers/serviceController';
import { getAllUsers, updateUserBalance, getPendingPurchases, resolvePurchase, getSystemLogs } from '../controllers/adminController';
import { getMyTransfers, getMyPurchases } from '../controllers/historyController';
import { 
  sendMessage, getMessages, createGroup, getConversations, getAdminContact,
  leaveOrRemoveFromGroup, addMembersToGroup, deleteGroup, deleteMessage, clearHistory, editMessage, pinMessage,
  getGroupDetails, updateGroup 
} from '../controllers/chatController';
import { 
  createStory, getActiveStories, deleteStory, viewStory, reactToStory 
} from '../controllers/storyController';

import { authenticate, authorizeAdmin } from '../middlewares/authMiddleware';
import { authLimiter, contentLimiter, reportLimiter } from '../middlewares/rateLimiter';

const router = Router();

router.post('/auth/register', authLimiter, register);
router.post('/auth/login', authLimiter, login);
router.post('/auth/telegram', authLimiter, telegramAuth);
router.post('/auth/email-code', authLimiter, sendVerificationEmail);
router.post('/auth/google', authLimiter, googleAuth);

router.get('/user/profile', authenticate, getProfile);
router.put('/user/profile', authenticate, updateProfile);
router.post('/user/secure', authenticate, secureAccount); 
router.get('/user/search', authenticate, searchUser);
router.post('/user/contacts/sync', authenticate, syncContacts);
router.get('/user/contacts', authenticate, getContacts);

router.get('/history/transfers', authenticate, getMyTransfers);
router.get('/history/purchases', authenticate, getMyPurchases);

router.get('/chat/conversations', authenticate, getConversations);
router.get('/chat/admin', authenticate, getAdminContact);
router.post('/chat/send', authenticate, contentLimiter, sendMessage);
router.get('/chat/messages', authenticate, getMessages);
router.delete('/chat/message/:messageId', authenticate, deleteMessage);
router.delete('/chat/history/:otherUserId', authenticate, clearHistory); // YENİ EKLENEN
router.put('/chat/message/:messageId', authenticate, editMessage); 
router.put('/chat/message/:messageId/pin', authenticate, pinMessage); 

router.post('/chat/group', authenticate, contentLimiter, createGroup);
router.get('/chat/group/:groupId', authenticate, getGroupDetails); 
router.put('/chat/group/:groupId', authenticate, updateGroup); 
router.post('/chat/group/members', authenticate, addMembersToGroup); 
router.delete('/chat/group/members', authenticate, leaveOrRemoveFromGroup); 
router.delete('/chat/group/:groupId', authenticate, deleteGroup);

router.post('/story', authenticate, contentLimiter, createStory);
router.get('/stories', authenticate, getActiveStories);
router.delete('/story/:storyId', authenticate, deleteStory);
router.post('/story/view', authenticate, viewStory);
router.post('/story/react', authenticate, reactToStory);

router.post('/transfer', authenticate, transferTMT);
router.get('/services', authenticate, getServices);
router.post('/services/purchase', authenticate, purchaseService);

// YENİ: ŞİKAYET & ENGELLEME
router.post('/report', authenticate, reportLimiter, createReport);
router.post('/block', authenticate, reportLimiter, blockUser);
router.delete('/block/:blockedUserId', authenticate, unblockUser);
router.get('/blocks', authenticate, getBlocks);

router.get('/admin/users', authenticate, authorizeAdmin, getAllUsers);
router.put('/admin/users/balance', authenticate, authorizeAdmin, updateUserBalance);
router.get('/admin/purchases/pending', authenticate, authorizeAdmin, getPendingPurchases);
router.put('/admin/purchases/resolve', authenticate, authorizeAdmin, resolvePurchase);
router.get('/admin/logs', authenticate, authorizeAdmin, getSystemLogs);
router.get('/admin/reports', authenticate, authorizeAdmin, getReports);
router.put('/admin/reports/:id', authenticate, authorizeAdmin, resolveReport);

export default router;
