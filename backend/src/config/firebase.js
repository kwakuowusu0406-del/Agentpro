const admin = require('firebase-admin');
const { logger } = require('../utils/logger');

let firebaseApp;

function initFirebase() {
  try {
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      }),
    });
    logger.info('Firebase Admin initialized');
  } catch (error) {
    logger.error('Firebase init error:', error);
    throw error;
  }
}

function getMessaging() {
  if (!firebaseApp) throw new Error('Firebase not initialized');
  return admin.messaging();
}

module.exports = { initFirebase, getMessaging };
