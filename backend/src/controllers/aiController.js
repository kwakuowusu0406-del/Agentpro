const Anthropic = require('@anthropic-ai/sdk');
const { query, withTransaction } = require('../config/database');
const { logger } = require('../utils/logger');

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// CRITICAL: AI must NEVER ask for or mention MoMo PIN
const SYSTEM_PROMPT = `You are the Agent Pro Ghana AI Assistant — a helpful, knowledgeable, and friendly assistant built into the Agent Pro Ghana mobile app for Mobile Money agents and business owners in Ghana.

Your role is to:
1. Help users understand and use the Agent Pro Ghana app features
2. Assist with troubleshooting failed or pending Mobile Money transactions
3. Explain float management, reports, and commission calculations
4. Guide users through subscription renewal and marketplace features
5. Answer FAQs about MTN Mobile Money, Telecel Cash, and AT Money services
6. Provide business guidance for mobile money agent operations

About Agent Pro Ghana:
- Supported providers: MTN Mobile Money, Telecel Cash, AT Money
- Transaction types: Cash In, Cash Out, Send Money, Merchant Payments, Bill Payments, Airtime, Data Bundles
- Subscription: GH₵10/month (Business Plan) — paid via MTN MoMo to Agent Pro Ghana merchant number
- Market Centre: Marketplace for businesses to advertise (1% fee of listed price)
- Reports: Daily, weekly, monthly, yearly — PDF and CSV
- Float: Tracked per provider per branch; low float alerts available

ABSOLUTE RULES — You MUST follow these without exception:
1. NEVER ask for, suggest entering, or mention a Mobile Money PIN (MoMo PIN) in any context
2. NEVER store, repeat, or reference any financial credentials
3. If a user mentions their PIN, immediately say: "Please do not share your MoMo PIN with anyone, including this assistant. Your PIN is private and should only be entered on the official network USSD screen."
4. Always refer users to call the network provider (MTN: 100, Telecel: 100, AT: 100) for PIN issues
5. If you cannot resolve an issue, escalate to human support: support@agentproghana.com

Your tone should be:
- Friendly and professional
- Clear and simple (users may not be very technical)
- Encouraging and helpful
- Use Ghana-appropriate language when suitable (e.g., "Akwaaba" for welcome)

Currency is always Ghana Cedis (GH₵ or GHS).`;

// ─── Start or Continue Conversation ──────────────────────────

exports.chat = async (req, res) => {
  const { message, conversation_id } = req.body;
  const userId = req.user.id;

  try {
    let conversationId = conversation_id;
    let history = [];

    // Load existing conversation
    if (conversationId) {
      const convResult = await query(
        'SELECT * FROM ai_conversations WHERE id = $1 AND user_id = $2',
        [conversationId, userId]
      );

      if (convResult.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Conversation not found' });
      }

      const messagesResult = await query(
        'SELECT role, content FROM ai_messages WHERE conversation_id = $1 ORDER BY created_at ASC',
        [conversationId]
      );

      history = messagesResult.rows;
    } else {
      // Create new conversation
      const convResult = await query(
        `INSERT INTO ai_conversations (user_id, context)
         VALUES ($1, $2) RETURNING id`,
        [userId, JSON.stringify({
          role: req.user.role,
          company_id: req.user.company_id
        })]
      );
      conversationId = convResult.rows[0].id;
    }

    // Build messages for Claude API
    const messages = [
      ...history.map(m => ({ role: m.role, content: m.content })),
      { role: 'user', content: message }
    ];

    // Call Anthropic API
    const response = await anthropic.messages.create({
      model: 'claude-sonnet-5',
      max_tokens: 1000,
      system: SYSTEM_PROMPT,
      messages
    });

    const assistantMessage = response.content[0].text;
    const tokensUsed = response.usage?.input_tokens + response.usage?.output_tokens || 0;

    // Save messages to DB
    await withTransaction(async (client) => {
      await client.query(
        'INSERT INTO ai_messages (conversation_id, role, content) VALUES ($1, $2, $3)',
        [conversationId, 'user', message]
      );
      await client.query(
        'INSERT INTO ai_messages (conversation_id, role, content, tokens_used) VALUES ($1, $2, $3, $4)',
        [conversationId, 'assistant', assistantMessage, tokensUsed]
      );
      await client.query(
        'UPDATE ai_conversations SET updated_at = NOW() WHERE id = $1',
        [conversationId]
      );
    });

    res.json({
      success: true,
      data: {
        conversation_id: conversationId,
        message: assistantMessage,
        tokens_used: tokensUsed
      }
    });

  } catch (error) {
    logger.error('AI chat error:', error);

    if (error.status === 401) {
      return res.status(500).json({ success: false, message: 'AI service configuration error' });
    }
    if (error.status === 429) {
      return res.status(429).json({ success: false, message: 'AI service is busy. Please try again shortly.' });
    }

    res.status(500).json({ success: false, message: 'Failed to get AI response. Please try again.' });
  }
};

// ─── Get Conversation History ─────────────────────────────────

exports.getConversation = async (req, res) => {
  const { conversation_id } = req.params;

  try {
    const convResult = await query(
      'SELECT * FROM ai_conversations WHERE id = $1 AND user_id = $2',
      [conversation_id, req.user.id]
    );

    if (convResult.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Conversation not found' });
    }

    const messagesResult = await query(
      'SELECT id, role, content, tokens_used, created_at FROM ai_messages WHERE conversation_id = $1 ORDER BY created_at ASC',
      [conversation_id]
    );

    res.json({
      success: true,
      data: {
        conversation: convResult.rows[0],
        messages: messagesResult.rows
      }
    });
  } catch (error) {
    logger.error('Get conversation error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch conversation' });
  }
};

// ─── List User's Conversations ────────────────────────────────

exports.listConversations = async (req, res) => {
  const { page = 1, limit = 20 } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);

  try {
    const result = await query(
      `SELECT c.id, c.title, c.created_at, c.updated_at,
              (SELECT content FROM ai_messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message
       FROM ai_conversations c
       WHERE c.user_id = $1
       ORDER BY c.updated_at DESC
       LIMIT $2 OFFSET $3`,
      [req.user.id, parseInt(limit), offset]
    );

    res.json({ success: true, data: result.rows });
  } catch (error) {
    logger.error('List conversations error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch conversations' });
  }
};
