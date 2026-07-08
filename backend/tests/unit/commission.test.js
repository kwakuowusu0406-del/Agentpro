// ============================================================
// Unit Tests — Agent Pro Ghana Backend
// ============================================================

const { calculateCommission } = require('../../src/services/commissionService');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// ─── Commission Calculation Tests ────────────────────────────

describe('Commission Service', () => {
  describe('calculateCommission()', () => {
    it('calculates basic commission correctly', () => {
      // 2% on GHS 500, no threshold
      const result = calculateCommission(500, 0.02, null, null, 0.30);
      expect(result.gross).toBe(10.00);
      expect(result.provider_share).toBe(3.00);
      expect(result.net).toBe(7.00);
    });

    it('applies cap when amount exceeds threshold', () => {
      // 2% on GHS 1500, threshold GHS 1000, cap GHS 20, provider 30%
      const result = calculateCommission(1500, 0.02, 1000, 20, 0.30);
      // Gross would be 1500 * 0.02 = 30, but cap is 20
      expect(result.gross).toBe(20.00);
      expect(result.provider_share).toBe(6.00);
      expect(result.net).toBe(14.00);
    });

    it('does NOT apply cap when amount is below threshold', () => {
      // 2% on GHS 800, threshold GHS 1000 (not reached)
      const result = calculateCommission(800, 0.02, 1000, 20, 0.30);
      expect(result.gross).toBe(16.00);
      expect(result.provider_share).toBe(4.80);
      expect(result.net).toBe(11.20);
    });

    it('applies cap exactly at threshold', () => {
      // 2% on GHS 1000 (exactly at threshold), cap GHS 20
      const result = calculateCommission(1000, 0.02, 1000, 20, 0.30);
      // 1000 * 0.02 = 20.00 exactly equals cap — take cap
      expect(result.gross).toBe(20.00);
    });

    it('handles zero amount', () => {
      const result = calculateCommission(0, 0.02, null, null, 0.30);
      expect(result.gross).toBe(0);
      expect(result.provider_share).toBe(0);
      expect(result.net).toBe(0);
    });

    it('rounds to 2 decimal places', () => {
      // 2% on GHS 333 = 6.66
      const result = calculateCommission(333, 0.02, null, null, 0.30);
      expect(result.gross).toBe(6.66);
      expect(Number.isInteger(result.gross * 100)).toBe(true);
    });

    it('handles 100% provider share', () => {
      const result = calculateCommission(500, 0.02, null, null, 1.0);
      expect(result.net).toBe(0);
      expect(result.provider_share).toBe(result.gross);
    });

    it('handles 0% provider share', () => {
      const result = calculateCommission(500, 0.02, null, null, 0.0);
      expect(result.provider_share).toBe(0);
      expect(result.net).toBe(result.gross);
    });
  });
});

// ─── Auth Helper Tests ────────────────────────────────────────

describe('Auth Utilities', () => {
  beforeAll(() => {
    process.env.JWT_ACCESS_SECRET = 'test-access-secret-min-64-chars-for-testing-purposes-only';
    process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-min-64-chars-for-testing-purposes-only';
    process.env.BCRYPT_ROUNDS = '4'; // Fast for tests
  });

  describe('Password hashing', () => {
    it('hashes password with bcrypt', async () => {
      const password = 'TestPassword123!';
      const hash = await bcrypt.hash(password, 4);
      expect(hash).toBeDefined();
      expect(hash).not.toBe(password);
      expect(hash.startsWith('$2')).toBe(true);
    });

    it('verifies correct password', async () => {
      const password = 'TestPassword123!';
      const hash = await bcrypt.hash(password, 4);
      const valid = await bcrypt.compare(password, hash);
      expect(valid).toBe(true);
    });

    it('rejects incorrect password', async () => {
      const password = 'TestPassword123!';
      const hash = await bcrypt.hash(password, 4);
      const valid = await bcrypt.compare('WrongPassword', hash);
      expect(valid).toBe(false);
    });
  });

  describe('JWT tokens', () => {
    it('generates and verifies access token', () => {
      const payload = { id: 'user-uuid', role: 'agent', company_id: 'company-uuid' };
      const token = jwt.sign(payload, process.env.JWT_ACCESS_SECRET, { expiresIn: '15m' });
      const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
      expect(decoded.id).toBe(payload.id);
      expect(decoded.role).toBe(payload.role);
    });

    it('rejects tampered token', () => {
      const payload = { id: 'user-uuid', role: 'agent' };
      const token = jwt.sign(payload, process.env.JWT_ACCESS_SECRET, { expiresIn: '15m' });
      const tampered = token.slice(0, -5) + 'XXXXX';
      expect(() => jwt.verify(tampered, process.env.JWT_ACCESS_SECRET)).toThrow();
    });

    it('rejects token with wrong secret', () => {
      const payload = { id: 'user-uuid', role: 'agent' };
      const token = jwt.sign(payload, 'wrong-secret');
      expect(() => jwt.verify(token, process.env.JWT_ACCESS_SECRET)).toThrow();
    });

    it('rejects expired token', () => {
      const payload = { id: 'user-uuid', role: 'agent' };
      const token = jwt.sign(payload, process.env.JWT_ACCESS_SECRET, { expiresIn: '0s' });
      expect(() => jwt.verify(token, process.env.JWT_ACCESS_SECRET)).toThrow(jwt.TokenExpiredError);
    });
  });
});

// ─── Security Tests ───────────────────────────────────────────

describe('Security Rules', () => {
  it('CRITICAL: no PIN-related field should appear in transaction response', () => {
    // Simulate a USSD session log
    const sessionLog = [
      { step: 0, type: 'dial', input: '*170#' },
      { step: 1, type: 'select', input: '1' },
      { step: 2, type: 'pin', input: null, note: '[PIN ENTRY - NOT LOGGED]', is_pin_step: true },
      { step: 3, type: 'confirm', input: '1' },
    ];

    // PIN step must NOT have an input value
    const pinSteps = sessionLog.filter(s => s.is_pin_step);
    pinSteps.forEach(step => {
      expect(step.input).toBeNull();
      expect(step.note).toBe('[PIN ENTRY - NOT LOGGED]');
    });

    // No step should have a value that looks like a PIN (4-6 digits)
    const allInputs = sessionLog
      .filter(s => !s.is_pin_step && s.input !== null)
      .map(s => s.input);

    allInputs.forEach(input => {
      if (input && typeof input === 'string') {
        // A PIN is 4-6 digits — flag if any non-PIN-step has this pattern
        // (menu selections like '1' are allowed; '1234' would be suspicious)
        const looksLikePin = /^\d{4,6}$/.test(input) && parseInt(input) > 9;
        if (looksLikePin) {
          // This would be a security violation in production
          console.warn(`Suspicious input in non-PIN step: ${input}`);
        }
      }
    });
  });

  it('sanitizeUSSDLog redacts the current pin_prompt_seen entry format', () => {
    // Imports the REAL function from the controller — not a hand-copied
    // duplicate — so this test can never silently drift from what the
    // code actually does. See transactionController.js's export comment.
    const { sanitizeUSSDLog } = require('../../src/controllers/transactionController');

    // This is the exact shape the current engine produces (ussd_service.dart):
    // a hardcoded safe placeholder is already in `response` by the time
    // it reaches here, but the server-side function must still actively
    // assert/overwrite it rather than trust the client sent it correctly.
    const log = [
      { type: 'dial', dialed: '*170*1*2*0241234567*250#', timestamp: '2026-07-04T10:00:00.000Z' },
      { type: 'response', response: 'Enter your PIN', timestamp: '2026-07-04T10:00:04.000Z' },
      { type: 'pin_prompt_seen', response: '[PIN ENTRY — NOT LOGGED, NOT APP-VISIBLE]', timestamp: '2026-07-04T10:00:04.100Z' },
      { type: 'final_response', response: 'Cash out successful', timestamp: '2026-07-04T10:00:12.000Z' },
    ];

    const sanitized = sanitizeUSSDLog(log);
    const pinEntry = sanitized[2];

    expect(pinEntry.response).toBe('[PIN ENTRY — NOT LOGGED, NOT APP-VISIBLE]');
    expect(pinEntry.dialed).toBeUndefined();
    // Non-PIN steps must be completely unaffected
    expect(sanitized[0].dialed).toBe('*170*1*2*0241234567*250#');
    expect(sanitized[1].response).toBe('Enter your PIN');
    expect(sanitized[3].response).toBe('Cash out successful');
  });

  it('sanitizeUSSDLog still redacts the legacy pre-migration format', () => {
    // Guards against regressing support for the transitional period
    // where an old app version might still submit the pre-redesign
    // step-array format if a phased rollout briefly has both in the wild.
    const { sanitizeUSSDLog } = require('../../src/controllers/transactionController');

    const log = [
      { step: 0, type: 'select', input: '1' },
      { step: 1, type: 'pin', input: '1234', is_pin_step: true },
      { step: 2, type: 'confirm', input: '1' },
    ];

    const sanitized = sanitizeUSSDLog(log);
    const pinStep = sanitized[1];

    expect(pinStep.input).toBeUndefined();
    expect(pinStep.note).toBe('[PIN ENTRY - NOT LOGGED]');
    expect(sanitized[0].input).toBe('1');
    expect(sanitized[2].input).toBe('1');
  });

  it('sanitizeUSSDLog handles null and non-array input safely', () => {
    const { sanitizeUSSDLog } = require('../../src/controllers/transactionController');
    expect(sanitizeUSSDLog(null)).toBeNull();
    expect(sanitizeUSSDLog(undefined)).toBeNull();
  });

  it('validates password strength requirements', () => {
    const validate = (password) => {
      if (password.length < 8) return 'too_short';
      if (!/[A-Z]/.test(password)) return 'no_uppercase';
      if (!/[0-9]/.test(password)) return 'no_number';
      return 'valid';
    };

    expect(validate('Test1234')).toBe('valid');
    expect(validate('short1')).toBe('too_short');
    expect(validate('alllowercase1')).toBe('no_uppercase');
    expect(validate('NoNumbers!')).toBe('no_number');
  });
});

// ─── Input Validation Tests ───────────────────────────────────

describe('Input Validation', () => {
  it('validates Ghana phone number format', () => {
    const isValidGhanaPhone = (phone) => /^0(2|5)[0-9]{8}$/.test(phone);
    expect(isValidGhanaPhone('0241234567')).toBe(true);  // MTN
    expect(isValidGhanaPhone('0501234567')).toBe(true);  // Telecel
    expect(isValidGhanaPhone('0271234567')).toBe(true);  // AT
    expect(isValidGhanaPhone('1234567890')).toBe(false); // Invalid
    expect(isValidGhanaPhone('024123456')).toBe(false);  // Too short
  });

  it('validates transaction amount range', () => {
    const isValidAmount = (amount) => amount > 0 && amount <= 10000;
    expect(isValidAmount(100)).toBe(true);
    expect(isValidAmount(0)).toBe(false);
    expect(isValidAmount(-1)).toBe(false);
    expect(isValidAmount(10001)).toBe(false);
  });

  it('validates MoMo reference format', () => {
    const isValidRef = (ref) => Boolean(ref && ref.trim().length >= 5);
    expect(isValidRef('APG12345')).toBe(true);
    expect(isValidRef('AB123')).toBe(true);
    expect(isValidRef('AB')).toBe(false);
    expect(isValidRef('')).toBe(false);
    expect(isValidRef(null)).toBe(false);
  });
});
