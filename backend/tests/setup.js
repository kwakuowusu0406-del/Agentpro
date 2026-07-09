/**
 * Test setup: Mock ALL external dependencies BEFORE any imports
 * This runs BEFORE Jest loads test files
 */

process.env.NODE_ENV = 'test';
process.env.JWT_ACCESS_SECRET = 'test-secret-key';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';
process.env.BCRYPT_ROUNDS = '10';

// Mock database before any requires
jest.mock('../src/config/database', () => {
  const mockQuery = jest.fn();
  
  // Mock user queries to return nothing (simulating no user found)
  mockQuery.mockImplementation((sql, params) => {
    if (sql && sql.includes('FROM users')) {
      return Promise.resolve({ rows: [] });
    }
    return Promise.resolve({ rows: [] });
  });

  return {
    connectDB: jest.fn().mockResolvedValue(undefined),
    query: mockQuery,
    pool: {
      query: jest.fn().mockResolvedValue({ rows: [] })
    },
    withTransaction: jest.fn((callback) => callback({
      query: jest.fn().mockResolvedValue({ rows: [] })
    }))
  };
});

// Mock Redis BEFORE any requires
jest.mock('../src/config/redis', () => {
  const mockRedisClient = {
    connect: jest.fn().mockResolvedValue(undefined),
    on: jest.fn(),
    set: jest.fn().mockResolvedValue('OK'),
    get: jest.fn().mockResolvedValue(null),
    del: jest.fn().mockResolvedValue(0),
    exists: jest.fn().mockResolvedValue(0),  // Token NOT blacklisted
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
    isTokenBlacklisted: jest.fn().mockResolvedValue(0),  // Token NOT blacklisted
    storeOTP: jest.fn().mockResolvedValue('OK'),
    getOTP: jest.fn().mockResolvedValue(null),
    deleteOTP: jest.fn().mockResolvedValue(0),
    get redisClient() { return mockRedisClient; }
  };
});

// Mock Firebase BEFORE any requires
jest.mock('../src/config/firebase', () => ({
  initFirebase: jest.fn(),
  sendNotification: jest.fn().mockResolvedValue(undefined)
}));

// Mock services that use real resources
jest.mock('../src/services/emailService', () => ({
  sendPasswordResetEmail: jest.fn().mockResolvedValue(undefined),
  sendWelcomeEmail: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../src/services/auditService', () => ({
  auditLog: jest.fn().mockResolvedValue(undefined)
}));

module.exports = {};
