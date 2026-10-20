# frozen_string_literal: true

module DiscourseWorkflows
  module AdminAssistant
    class WorkflowDraft < DiscourseAi::Agents::Tools::DraftReference
      SENSITIVE_KEYS = %w[
        password
        secret
        secret_key
        token
        auth_token
        bearer_token
        credential
        credentials
        api_key
        authorization
        private_key
        client_secret
        access_token
        refresh_token
      ].freeze
      SENSITIVE_TEXT =
        %r{
          (?:
            \b(?:password|secret|token|credential|api[ _-]?key|authorization|
              private[ _-]?key|client[ _-]?secret|access[ _-]?token|refresh[ _-]?token)\b
            \s*(?:is|:|=)\s*["']?\S{4,}
            |
            \bbearer\s+[a-z0-9._~+\/-]{8,}
          )
        }ix
      PRIVATE_KEY_TEXT = /-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----/
      JWT_TEXT = /\beyJ[a-z0-9_-]{8,}\.eyJ[a-z0-9_-]{8,}\.[a-z0-9_-]{8,}\b/i
      PROVIDER_KEY_TEXT = /\b(?:AKIA|ASIA)[A-Z0-9]{16}\b|\b(?:gh[pousr]_|sk-)[a-z0-9_-]{20,}\b/i
      URL_CREDENTIALS_TEXT = %r{\b[a-z][a-z0-9+.-]*://[^/\s:@]+:[^/\s@]+@}i

      def self.contains_secret?(value, key: nil)
        return true if SENSITIVE_KEYS.include?(key.to_s.underscore) && value.present?

        case value
        when Hash
          value.any? { |nested_key, nested_value| contains_secret?(nested_value, key: nested_key) }
        when Array
          value.any? { |nested_value| contains_secret?(nested_value) }
        else
          value.is_a?(String) && contains_secret_text?(value)
        end
      end

      def self.contains_secret_text?(value)
        [
          SENSITIVE_TEXT,
          PRIVATE_KEY_TEXT,
          JWT_TEXT,
          PROVIDER_KEY_TEXT,
          URL_CREDENTIALS_TEXT,
        ].any? { |pattern| pattern.match?(value.to_s) }
      end

      class << self
        private

        def draft_kind
          "workflow"
        end

        def reference_prefix
          "workflow_authoring_draft_"
        end
      end
    end
  end
end
