-- ============================================================
-- Migration 002: Redesign USSD templates for single-shot dialing
-- ============================================================
--
-- WHY THIS MIGRATION EXISTS:
-- The original `menu_steps` design assumed the app could dial a USSD
-- code, then send a sequence of follow-up inputs (menu selections,
-- phone number, amount) one at a time via a "reply" API call.
--
-- Android's public TelephonyManager.sendUssdRequest() API does not
-- support this. It is a single request -> single response API: you
-- dial once, you get exactly one callback with the network's reply.
-- There is no public Android API for a third-party app to send a
-- follow-up input into an already-open interactive USSD session.
-- (Confirmed against multiple independent sources, including a
-- purpose-built library for this exact problem reporting the same
-- limitation: https://github.com/vkammerer/ussd_service/issues/1)
--
-- The fix: instead of a step-by-step menu tree, a template now stores
-- ONE pattern string with placeholders (e.g. '*170*2*1*{phone}*{amount}#')
-- that gets fully resolved and dialed as a single sendUssdRequest()
-- call. This is the standard approach used by USSD automation apps
-- that avoid Android's AccessibilityService (which this app's spec
-- explicitly avoids using).
--
-- PIN entry remains a deliberate exception: it is not concatenated
-- into the dial string (that would mean the PIN briefly exists in
-- the phone's dial/call history — a real security anti-pattern the
-- network operators themselves avoid). Instead, if the network's
-- response indicates a PIN prompt is needed, the OS's own USSD
-- session handling takes over for that one exchange, independent of
-- this app — the same way PIN entry has always worked here. The app
-- never sees or transmits the PIN in any form, at any layer.
-- ============================================================

-- Drop the old per-step columns; add the new pattern-based ones.
-- ussd_code is also dropped: it's now fully redundant with
-- ussd_string_pattern (the pattern already contains the base code,
-- e.g. '*170' is the prefix of '*170*1*2*{customer_phone}*{amount}#'),
-- and keeping both invites them to drift out of sync.
ALTER TABLE ussd_templates
  DROP COLUMN IF EXISTS menu_steps,
  DROP COLUMN IF EXISTS pin_step_index,
  DROP COLUMN IF EXISTS ussd_code;

ALTER TABLE ussd_templates
  ADD COLUMN ussd_string_pattern VARCHAR(200),
  ADD COLUMN pin_prompt_strings TEXT[] NOT NULL DEFAULT ARRAY['pin', 'enter your pin', 'enter pin'],
  ADD COLUMN placeholder_fields TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

COMMENT ON COLUMN ussd_templates.ussd_string_pattern IS
  'Single USSD string with {placeholder} tokens (e.g. amount, customer_phone), '
  'dialed as ONE sendUssdRequest() call. Never include a PIN placeholder here.';

COMMENT ON COLUMN ussd_templates.pin_prompt_strings IS
  'Substrings that, if found in the network''s response, indicate a PIN '
  'prompt is being shown by the OS. The engine pauses and waits for the '
  'session to resolve rather than trying to reply to this prompt itself.';

COMMENT ON COLUMN ussd_templates.placeholder_fields IS
  'Which {placeholder} tokens this template actually uses, for validation '
  'in the admin portal template editor (e.g. [''amount'', ''customer_phone'']).';

-- Deactivate all existing templates BEFORE adding the CHECK constraint
-- below. Existing rows have is_active = TRUE (the old default) but no
-- ussd_string_pattern yet (it's a brand new column) — adding a CHECK
-- constraint validates it against every existing row immediately, not
-- just future inserts, so this would otherwise fail on any database
-- that already ran the original seed script.
--
-- The accompanying updated seed script re-activates each template as
-- it fills in a real ussd_string_pattern.
UPDATE ussd_templates SET is_active = FALSE WHERE ussd_string_pattern IS NULL;

-- ussd_string_pattern is required for any active template going forward.
ALTER TABLE ussd_templates
  ADD CONSTRAINT ussd_string_pattern_required_when_active
  CHECK (is_active = FALSE OR ussd_string_pattern IS NOT NULL);

-- The single-dial redesign introduces a genuine third transaction
-- outcome (pending_confirmation) alongside success/failed: when the
-- network never confirms an outcome after a PIN prompt, we honestly
-- don't know whether money moved, and must not tell the agent it's
-- safe to retry as if it definitely failed. This needs its own
-- notification type so agents see an accurate message, not one
-- silently folded into "transaction failed".
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'transaction_pending_confirmation';

-- Defense-in-depth for retry_count, matching the same bound the
-- Flutter engine actually respects (`retryCount.clamp(0, 3)` in
-- ussd_service.dart). Without this, a value outside that range could
-- be written by some future code path that bypasses the admin API's
-- application-level validation (e.g. a direct DB edit, or a script),
-- leaving the stored value silently disconnected from real app
-- behavior — exactly the kind of mismatch the admin API validation
-- was added to prevent at that layer; this closes the same gap at
-- the data layer too.
ALTER TABLE ussd_templates
  ADD CONSTRAINT retry_count_within_engine_bounds
  CHECK (retry_count BETWEEN 0 AND 3);
