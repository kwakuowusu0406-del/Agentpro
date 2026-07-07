const Redis = require('ioredis');
const { logger } = require('../utils/logger');

let redisClient;

function connectRedis() {
  return new Promise((resolve, reject) => {
    redisClient = new Redis(process.env.REDIS_URL, {
      maxRetriesPerRequest: 3,
      retryStrategy: (times) => Math.min(times * 100, 3000),
      lazyConnect: true
    });

    redisClient.on('connect', () => {
      logger.info('Redis connected');
      resolve();
    });

    redisClient.on('error', (err) => {
      logger.error('Redis error:', err);
      if (!redisClient.status || redisClient.status === 'close') {
        reject(err);
      }
    });

    redisClient.connect().catch(reject);
  });
}

/**
 * Set key with optional TTL (seconds)
 */
async function setCache(key, value, ttlSeconds = null) {
  const serialized = JSON.stringify(value);
  if (ttlSeconds) {
    return redisClient.setex(`agentpro:${key}`, ttlSeconds, serialized);
  }
  return redisClient.set(`agentpro:${key}`, serialized);
}

/**
 * Get cached value
 */
async function getCache(key) {
  const value = await redisClient.get(`agentpro:${key}`);
  return value ? JSON.parse(value) : null;
}

/**
 * Delete cached value
 */
async function deleteCache(key) {
  return redisClient.del(`agentpro:${key}`);
}

/**
 * Blacklist a JWT token (for logout / revocation)
 */
async function blacklistToken(token, expiresIn) {
  return redisClient.setex(`blacklist:${token}`, expiresIn, '1');
}

/**
 * Check if token is blacklisted
 */
async function isTokenBlacklisted(token) {
  return redisClient.exists(`blacklist:${token}`);
}

/**
 * Store OTP or reset token
 */
async function storeOTP(key, value, ttlSeconds = 3600) {
  return redisClient.setex(`otp:${key}`, ttlSeconds, value);
}

async function getOTP(key) {
  return redisClient.get(`otp:${key}`);
}

async function deleteOTP(key) {
  return redisClient.del(`otp:${key}`);
}

module.exports = {
  get redisClient() { return redisClient; },
  connectRedis,
  setCache,
  getCache,
  deleteCache,
  blacklistToken,
  isTokenBlacklisted,
  storeOTP,
  getOTP,
  deleteOTP
};
