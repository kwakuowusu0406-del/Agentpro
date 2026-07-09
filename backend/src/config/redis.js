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
  try {
    const serialized = JSON.stringify(value);
    if (ttlSeconds) {
      return redisClient.setex(`agentpro:${key}`, ttlSeconds, serialized);
    }
    return redisClient.set(`agentpro:${key}`, serialized);
  } catch (error) {
    logger.error('Cache set error:', error);
    return null;
  }
}

/**
 * Get cached value
 */
async function getCache(key) {
  try {
    const value = await redisClient.get(`agentpro:${key}`);
    return value ? JSON.parse(value) : null;
  } catch (error) {
    logger.error('Cache get error:', error);
    return null;
  }
}

/**
 * Delete cached value
 */
async function deleteCache(key) {
  try {
    return redisClient.del(`agentpro:${key}`);
  } catch (error) {
    logger.error('Cache delete error:', error);
    return null;
  }
}

/**
 * Blacklist a JWT token (for logout / revocation)
 */
async function blacklistToken(token, expiresIn) {
  try {
    return redisClient.setex(`blacklist:${token}`, expiresIn, '1');
  } catch (error) {
    logger.error('Blacklist token error:', error);
    return null;
  }
}

/**
 * Check if token is blacklisted
 */
async function isTokenBlacklisted(token) {
  try {
    if (!redisClient) {
      return 0; // Not blacklisted if Redis unavailable
    }
    return await redisClient.exists(`blacklist:${token}`);
  } catch (error) {
    logger.error('Blacklist check error:', error);
    return 0; // Not blacklisted if check fails
  }
}

/**
 * Store OTP or reset token
 */
async function storeOTP(key, value, ttlSeconds = 3600) {
  try {
    return redisClient.setex(`otp:${key}`, ttlSeconds, value);
  } catch (error) {
    logger.error('OTP store error:', error);
    return null;
  }
}

async function getOTP(key) {
  try {
    return redisClient.get(`otp:${key}`);
  } catch (error) {
    logger.error('OTP get error:', error);
    return null;
  }
}

async function deleteOTP(key) {
  try {
    return redisClient.del(`otp:${key}`);
  } catch (error) {
    logger.error('OTP delete error:', error);
    return null;
  }
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
