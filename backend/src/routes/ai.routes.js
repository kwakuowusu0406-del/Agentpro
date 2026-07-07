const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const aiController = require('../controllers/aiController');
const { authenticate } = require('../middleware/auth');
const rateLimit = require('express-rate-limit');

// AI-specific rate limit: 30 messages per minute
const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  message: { success: false, message: 'Too many AI requests. Please wait a moment.' },
});

router.use(authenticate, aiLimiter);

router.post('/chat', [
  body('message').trim().notEmpty().isLength({ max: 2000 }).withMessage('Message is required (max 2000 chars)'),
], aiController.chat);

router.get('/conversations', aiController.listConversations);
router.get('/conversations/:conversation_id', aiController.getConversation);

module.exports = router;
