# frozen_string_literal: true

module DiscourseWorkflows
  class FormTriggerToken
    PURPOSE = "discourse-workflows-form-trigger".freeze
    SALT = "discourse-workflows-form-trigger".freeze
    KEY_LENGTH = 32
    TTL = 1.hour

    def self.generate(workflow_id:, trigger_node_id:, uuid:)
      verifier.generate(
        {
          "workflow_id" => workflow_id,
          "trigger_node_id" => trigger_node_id.to_s,
          "uuid" => uuid,
          "nonce" => SecureRandom.hex(16),
        },
        purpose: PURPOSE,
        expires_in: TTL,
      )
    end

    def self.valid?(token, workflow_id:, trigger_node_id:, uuid:)
      payload = verify(token)
      return false if payload.blank?

      payload["workflow_id"].to_s == workflow_id.to_s &&
        payload["trigger_node_id"].to_s == trigger_node_id.to_s && payload["uuid"].to_s == uuid.to_s
    end

    def self.verify(token)
      verifier.verified(token, purpose: PURPOSE)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def self.verifier
      @verifier ||=
        ActiveSupport::MessageVerifier.new(
          ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
            SALT,
            KEY_LENGTH,
          ),
          digest: "SHA256",
          serializer: JSON,
        )
    end
    private_class_method :verifier
  end
end
