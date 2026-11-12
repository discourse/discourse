# frozen_string_literal: true

module DiscourseWorkflows
  class WaitingExecution
    SIGNATURE_PARAM = "signature"
    SIGNATURE_SALT = "discourse-workflows-waiting-signature"
    ACTION_TOKEN_SALT = "discourse-workflows-waiting-action"
    FORM_CHANNEL_SALT = "discourse-workflows-form-channel"
    HMAC_KEY_LENGTH = 32

    def self.find(execution_id:, signature:, expected_node_type: nil)
      execution =
        DiscourseWorkflows::Execution.includes(:workflow).find_by(
          id: execution_id,
          status: :waiting,
        )
      return unless execution
      return unless valid_signature?(execution, signature)

      if expected_node_type.present?
        waiting_node = execution.find_waiting_node
        return unless waiting_node&.dig("type") == expected_node_type
      end

      execution
    end

    def self.valid_signature?(execution, signature)
      stored =
        resume_signature(execution_id: execution.id, resume_token: execution.resume_token).to_s
      provided = signature.to_s
      return false if stored.blank? || provided.blank?
      return false if stored.bytesize != provided.bytesize

      ActiveSupport::SecurityUtils.secure_compare(stored, provided)
    end

    def self.claim(execution, signature:)
      return unless valid_signature?(execution, signature)

      DiscourseWorkflows::Execution.claim_for_resume(
        execution,
        resume_token: execution.resume_token,
      )
    end

    def self.resume_claimed(execution, response_items, user: nil, webhook_context: nil)
      DiscourseWorkflows::Executor.resume(
        execution,
        response_items,
        user: user,
        webhook_context: webhook_context,
      )
    end

    def self.form_urls(execution)
      {
        form_channel: form_channel(execution),
        form_waiting_url: form_waiting_url(execution),
        form_submit_url: form_waiting_url(execution),
        form_status_url: form_status_url(execution),
      }
    end

    def self.form_waiting_url(execution, absolute: false)
      form_waiting_url_for(
        execution_id: execution.id,
        resume_token: execution.resume_token,
        absolute: absolute,
      )
    end

    def self.form_waiting_url_for(execution_id:, resume_token:, absolute: false)
      signed_url(
        "/workflows/forms/waiting/#{execution_id.to_i}.json",
        resume_signature(execution_id: execution_id, resume_token: resume_token),
        absolute: absolute,
      )
    end

    def self.form_status_url(execution, absolute: false)
      form_status_url_for(
        execution_id: execution.id,
        resume_token: execution.resume_token,
        absolute: absolute,
      )
    end

    def self.form_status_url_for(execution_id:, resume_token:, absolute: false)
      signed_url(
        "/workflows/forms/waiting/#{execution_id.to_i}/status.json",
        resume_signature(execution_id: execution_id, resume_token: resume_token),
        absolute: absolute,
      )
    end

    def self.form_channel(execution)
      resume_token = execution.resume_token.to_s
      return if resume_token.blank?

      signature =
        OpenSSL::HMAC.hexdigest("SHA256", form_channel_key, "#{execution.id}:#{resume_token}")
      "/discourse-workflows/form-execution/#{execution.id}-#{signature}"
    end

    def self.webhook_url(execution_id:, resume_token:, suffix: nil, absolute: true)
      webhook_url_with_signature(
        execution_id: execution_id,
        signature: resume_signature(execution_id: execution_id, resume_token: resume_token),
        suffix: suffix,
        absolute: absolute,
      )
    end

    def self.webhook_url_with_signature(execution_id:, signature:, suffix: nil, absolute: true)
      path = "/workflows/waiting/#{execution_id}/webhook"
      path = "#{path}/#{suffix}" if suffix.present?
      signed_url(path, signature, absolute: absolute)
    end

    def self.action_token(execution_id:, resume_token:, action:, target_user_id: nil)
      action = action.to_s
      signature = action_signature(execution_id:, resume_token:, action:, target_user_id:)
      "#{execution_id.to_i}:#{target_user_id}:#{action}:#{signature}"
    end

    def self.action_token_payload(token)
      return if token.blank?

      execution_id, target_user_id, action, signature = token.to_s.split(":", 4)
      return if execution_id.blank? || action.blank? || signature.blank?
      return unless execution_id.match?(/\A\d+\z/)
      return unless target_user_id.blank? || target_user_id.match?(/\A\d+\z/)

      {
        "execution_id" => execution_id.to_i,
        "target_user_id" => target_user_id.presence&.to_i,
        "action" => action,
        "signature" => signature,
      }
    end

    def self.find_by_action_token(token, expected_node_type:)
      payload = action_token_payload(token)
      return unless payload

      execution =
        DiscourseWorkflows::Execution.includes(:workflow).find_by(
          id: payload["execution_id"],
          status: :waiting,
        )
      return unless execution
      return unless valid_action_signature?(execution, payload)

      if expected_node_type.present?
        waiting_node = execution.find_waiting_node
        return unless waiting_node&.dig("type") == expected_node_type
      end

      execution
    end

    def self.signed_url(path, signature, absolute: false)
      base = absolute ? Discourse.base_url : ""
      separator = path.include?("?") ? "&" : "?"
      "#{base}#{path}#{separator}#{SIGNATURE_PARAM}=#{Rack::Utils.escape(signature.to_s)}"
    end
    private_class_method :signed_url

    def self.resume_signature(execution_id:, resume_token:)
      resume_token = resume_token.to_s
      return if resume_token.blank?

      OpenSSL::HMAC.hexdigest("SHA256", signature_key, "#{execution_id.to_i}:#{resume_token}")
    end

    def self.valid_action_signature?(execution, payload)
      signature = payload["signature"].to_s
      expected =
        action_signature(
          execution_id: execution.id,
          resume_token: execution.resume_token,
          action: payload["action"],
          target_user_id: payload["target_user_id"],
        )
      return false if signature.bytesize != expected.bytesize

      ActiveSupport::SecurityUtils.secure_compare(signature, expected)
    end
    private_class_method :valid_action_signature?

    def self.action_signature(execution_id:, resume_token:, action:, target_user_id: nil)
      OpenSSL::HMAC.hexdigest(
        "SHA256",
        action_token_key,
        "#{execution_id.to_i}:#{target_user_id}:#{action}:#{resume_token}",
      )
    end
    private_class_method :action_signature

    def self.action_token_key
      @action_token_key ||=
        ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
          ACTION_TOKEN_SALT,
          HMAC_KEY_LENGTH,
        )
    end
    private_class_method :action_token_key

    def self.signature_key
      @signature_key ||=
        ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
          SIGNATURE_SALT,
          HMAC_KEY_LENGTH,
        )
    end
    private_class_method :signature_key

    def self.form_channel_key
      @form_channel_key ||=
        ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
          FORM_CHANNEL_SALT,
          HMAC_KEY_LENGTH,
        )
    end
    private_class_method :form_channel_key
  end
end
