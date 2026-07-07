const { query } = require('../config/database');
const { logger } = require('../utils/logger');

/**
 * Record an audit log entry
 */
async function auditLog({
  userId,
  companyId,
  action,
  entityType,
  entityId,
  oldValues,
  newValues,
  ipAddress,
  userAgent,
  requestId,
  result = 'success',
  errorMessage
}) {
  try {
    await query(
      `INSERT INTO audit_logs (
        user_id, company_id, action, entity_type, entity_id,
        old_values, new_values, ip_address, user_agent,
        request_id, result, error_message
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
      [
        userId || null,
        companyId || null,
        action,
        entityType || null,
        entityId || null,
        oldValues ? JSON.stringify(oldValues) : null,
        newValues ? JSON.stringify(newValues) : null,
        ipAddress || null,
        userAgent || null,
        requestId || null,
        result,
        errorMessage || null
      ]
    );
  } catch (error) {
    // Audit logging should never break the application
    logger.error('Audit log write error:', error);
  }
}

module.exports = { auditLog };
