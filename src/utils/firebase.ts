const admin = require('firebase-admin');

const initializeFirebase = () => {
  try {
    if (!admin.apps.length) {
      if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY) {
        
        if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
          admin.initializeApp({
           credential: admin.credential.applicationDefault(),
          });
        } else if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY) {
           let privateKey = process.env.FIREBASE_PRIVATE_KEY;
          if (privateKey.includes('\\n')) {
             privateKey = privateKey.replace(/\\n/g, '\n');
          }
          admin.initializeApp({
            credential: admin.credential.cert({
            projectId: process.env.FIREBASE_PROJECT_ID,
            clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
            privateKey: privateKey,
            }),
          });
        }
        console.log("Firebase Admin strin mode başarıyla başlatıldı!");
      } else {
        console.warn("DİKKAT: VPS üzerinde FIREBASE_PRIVATE_KEY vb. değişkenler BULUNAMADI!");
      }
    }
  } catch (error) {
    console.error("Firebase Initialization ERROR: ", error);
  }
};

initializeFirebase();

export const sendNotification = async (fcmToken: string, title: string, body: string, dataPayload: any = {}) => {
  if (!fcmToken) {
    console.log('FCM Token eksik, bildirim atlanıyor.');
    return;
  }
  
  if (!admin.apps.length) {
    console.log('Firebase App başlatılamadığı için bildirim gönderilemiyor.');
    return;
  }
  
  const message = {
    notification: { 
      title: title, 
      body: body 
    },
    data: dataPayload,
    token: fcmToken,
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'high_importance_channel',
      }
    }
  };

  try {
    const response = await admin.messaging().send(message);
    console.log(`Bildirim başarıyla gönderildi:`, response);
  } catch (error) {
    console.error(`Bildirim gönderilirken hata oluştu:`, error);
  }
};