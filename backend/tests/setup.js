/**
 * Test setup: Mock ALL external dependencies BEFORE server.js loads
 */

process.env.NODE_ENV = 'test';
process.env.JWT_ACCESS_SECRET = 'test-secret-key';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';
process.env.BCRYPT_ROUNDS = '10';
process.env.APP_NAME = 'Agent Pro Ghana';

// CRITICAL: Mock modules BEFORE server.js requires them
const mockQuery = jest.fn().mockImplementation((sql, params) => {
  // Return empty result for all queries
  return Promise.resolve({ rows: [] });
});

const mockRedisClient = {
  connect: jest.fn().mockResolvedValue(undefined),
  on: jest.fn(),
  ping: jest.fn().mockResolvedValue('PONG'),
  exists: jest.fn().mockResolvedValue(0),  // Not blacklisted
  get: jest.fn().mockResolvedValue(null),
  set: jest.fn().mockResolvedValue('OK'),
  setex: jest.fn().mockResolvedValue('OK'),
  del: jest.fn().mockResolvedValue(0),
  status: 'ready'
};

// Mock database module
jest.doMock('../src/config/database', () => ({
  connectDB: jest.fn().mockResolvedValue(undefined),
  query: mockQuery,
  pool: {
    query: mockQuery
  },
  withTransaction: jest.fn((callback) => {
    const mockClient = {
      query: mockQuery
    };
    return callback(mockClient);
  })
}));

// Mock Redis module
jest.doMock('../src/config/redis', () => ({
  connectRedis: jest.fn().mockResolvedValue(undefined),
  redisClient: mockRedisClient,
  isTokenBlacklisted: jest.fn().mockResolvedValue(0),  // Not blacklisted
  blacklistToken: jest.fn().mockResolvedValue(undefined),
  setCache: jest.fn().mockResolvedValue('OK'),
  getCache: jest.fn().mockResolvedValue(null),
  deleteCache: jest.fn().mockResolvedValue(0),
  storeOTP: jest.fn().mockResolvedValue('OK'),
  getOTP: jest.fn().mockResolvedValue(null),
  deleteOTP: jest.fn().mockResolvedValue(0)
}));

// Mock Firebase
jest.doMock('../src/config/firebase', () => ({
  initFirebase: jest.fn(),
  sendNotification: jest.fn().mockResolvedValue(undefined)
}));

// Mock email service
jest.doMock('../src/services/emailService', () => ({
  sendPasswordResetEmail: jest.fn().mockResolvedValue(undefined),
  sendWelcomeEmail: jest.fn().mockResolvedValue(undefined)
}));

// Mock audit service
jest.doMock('../src/services/auditService', () => ({
  auditLog: jest.fn().mockResolvedValue(undefined)
}));

module.exports = {};
