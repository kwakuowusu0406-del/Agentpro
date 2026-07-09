/**
 * Test setup: Mock external services to avoid connection failures in CI/CD
 */

jest.mock('../src/config/database', () => ({
  connectDB: jest.fn().mockResolvedValue(undefined),
  pool: {
    query: jest.fn().mockResolvedValue({ rows: [] })
  }
}));

jest.mock('../src/config/redis', () => {
  const mockRedisClient = {
    connect: jest.fn().mockResolvedValue(undefined),
    on: jest.fn(),
    set: jest.fn().mockResolvedValue('OK'),
    get: jest.fn().mockResolvedValue(null),
    del: jest.fn().mockResolvedValue(0),
    exists: jest.fn().mockResolvedValue(0),  // Token not blacklisted
    setex: jest.fn().mockResolvedValue('OK'),
    quit: jest.fn().mockResolvedValue(undefined),
    ping: jest.fn().mockResolvedValue('PONG'),
    status: 'ready'
  };

  return {
    connectRedis: jest.fn().mockResolvedValue(undefined),
    setCache: jest.fn().mockResolvedValue('OK'),
    getCache: jest.fn().mockResolvedValue(null),
    deleteCache: jest.fn().mockResolvedValue(0),
    blacklistToken: jest.fn().mockResolvedValue('OK'),
    isTokenBlacklisted: jest.fn().mockResolvedValue(0),  // Token not blacklisted
    storeOTP: jest.fn().mockResolvedValue('OK'),
    getOTP: jest.fn().mockResolvedValue(null),
    deleteOTP: jest.fn().mockResolvedValue(0),
    get redisClient() { return mockRedisClient; }
  };
});

jest.mock('../src/config/firebase', () => ({
  initFirebase: jest.fn(),
  sendNotification: jest.fn().mockResolvedValue(undefined)
}));

module.exports = {};