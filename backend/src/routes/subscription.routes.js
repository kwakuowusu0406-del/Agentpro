const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const subController = require('../controllers/subscriptionController');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/status', subController.getSubscription);
router.get('/status/:company_id', authorize('superuser'), subController.getSubscription);

router.post('/payment', [
  body('momo_reference').trim().notEmpty().withMessage('MoMo reference is required'),
  body('payment_phone').trim().notEmpty().withMessage('Payment phone is required'),
], authorize('business_owner'), subController.submitPayment);

router.get('/pending-payments', authorize('superuser'), subController.listPendingPayments);
router.patch('/payment/:payment_id/verify', authorize('superuser'), subController.verifyPayment);

module.exports = router;
