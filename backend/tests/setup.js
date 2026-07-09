/**
 * Test setup: Mock Redis to avoid connection failures in CI/CD
 */

// Mock redis client for testing
const mockRedisClient = {
  connect: jest.fn().mockResolvedValue(undefined),
  on: jest.fn(),
  set: jest.fn().mockResolvedValue('OK'),
  get: jest.fn().mockResolvedValue(null),
  del: jest.fn().mockResolvedValue(0),
  exists: jest.fn().mockResolvedValue(0),  // Token not blacklisted
  setex: jest.fn().mockResolvedValue('OK'),
  quit: jest.fn().mockResolvedValue(undefined),
  status: 'ready',
  ping: jest.fn().mockResolvedValue('PONG')
};

jest.mock('../src/config/redis', () => ({
  connectRedis: jest.fn().mockResolvedValue(undefined),
  setCache: jest.fn().mockResolvedValue('OK'),
  getCache: jest.fn().mockResolvedValue(null),
  deleteCache: jest.fn().mockResolvedValue(0),
  blacklistToken: jest.fn().mockResolvedValue('OK'),
  isTokenBlacklisted: jest.fn().mockResolvedValue(0),  // Token not blacklisted
  storeOTP: jest.fn().mockResolvedValue('OK'),
  getOTP: jest.fn().mockResolvedValue(null),
  deleteOTP: jest.fn().mockResolvedValue(0),
  redisClient: mockRedisClient
}));

module.exports = {};