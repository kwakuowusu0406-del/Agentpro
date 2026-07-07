#!/usr/bin/env node
'use strict';

/**
 * Agent Pro Ghana — Database Migration Runner
 * Run: node scripts/migrate.js
 *
 * Applies all pending SQL migration files in order.
 * Tracks applied migrations in a migrations_log table.
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const { logger } = require('../src/utils/logger');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
});

async function migrate() {
  const client = await pool.connect();

  try {
    // Create migrations tracking table if it doesn't exist
    await client.query(`
      CREATE TABLE IF NOT EXISTS migrations_log (
        id SERIAL PRIMARY KEY,
        filename VARCHAR(255) NOT NULL UNIQUE,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // Get already-applied migrations
    const applied = await client.query('SELECT filename FROM migrations_log ORDER BY filename');
    const appliedSet = new Set(applied.rows.map(r => r.filename));

    // Read migration files
    const migrationsDir = path.join(__dirname, '../migrations');
    const files = fs.readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort(); // Applies in alphabetical/numeric order

    let count = 0;

    for (const file of files) {
      if (appliedSet.has(file)) {
        logger.info(`  ⏭  Skipping (already applied): ${file}`);
        continue;
      }

      logger.info(`  ▶  Applying: ${file}`);
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');

      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query(
          'INSERT INTO migrations_log (filename) VALUES ($1)',
          [file]
        );
        await client.query('COMMIT');
        logger.info(`  ✅ Applied: ${file}`);
        count++;
      } catch (err) {
        await client.query('ROLLBACK');
        logger.error(`  ❌ Failed: ${file}`, err.message);
        throw err;
      }
    }

    if (count === 0) {
      logger.info('✅ Database is up to date — no migrations to apply');
    } else {
      logger.info(`✅ Applied ${count} migration(s) successfully`);
    }
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch(err => {
  logger.error('Migration failed:', err);
  process.exit(1);
});
