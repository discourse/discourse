# frozen_string_literal: true

Fabricator(:ai_api_audit_log) { provider_id { AiApiAuditLog::Provider::OpenAI } }
