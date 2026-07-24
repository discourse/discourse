# frozen_string_literal: true

module DiscourseWorkflows
  class FormTriggerToken
    PURPOSE = "discourse-workflows-form-trigger"
    SALT = "discourse-workflows-form-trigger"
    KEY_LENGTH = 32
    TTL = 1.hour

    def self.generate(workflow_id:, trigger_node_id:, uuid:, form_query_parameters: nil)
      payload = {
        "workflow_id" => workflow_id,
        "trigger_node_id" => trigger_node_id.to_s,
        "uuid" => uuid,
        "nonce" => SecureRandom.hex(16),
      }

      normalized_query_parameters =
        DiscourseWorkflows::Forms::Payload.normalize_query_parameters(form_query_parameters)
      if normalized_query_parameters.present?
        payload["form_query_parameters"] = normalized_query_parameters
      end

      encryptor.encrypt_and_sign(JSON.generate(payload), purpose: PURPOSE, expires_in: TTL)
    end

    def self.valid?(token, workflow_id:, trigger_node_id:, uuid:)
      payload(
        token,
        workflow_id: workflow_id,
        trigger_node_id: trigger_node_id,
        uuid: uuid,
      ).present?
    end

    def self.payload(token, workflow_id:, trigger_node_id:, uuid:)
      payload = verify(token)
      return if payload.blank?

      if payload["workflow_id"].to_s == workflow_id.to_s &&
           payload["trigger_node_id"].to_s == trigger_node_id.to_s &&
           payload["uuid"].to_s == uuid.to_s
        payload
      end
    end

    def self.verify(token)
      decrypted = encryptor.decrypt_and_verify(token, purpose: PURPOSE)
      return if decrypted.blank?

      JSON.parse(decrypted)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, JSON::ParserError
      nil
    end

    def self.encryptor
      @encryptor ||=
        ActiveSupport::MessageEncryptor.new(
          ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
            SALT,
            KEY_LENGTH,
          ),
          cipher: "aes-256-gcm",
        )
    end
    private_class_method :encryptor
  end
end
