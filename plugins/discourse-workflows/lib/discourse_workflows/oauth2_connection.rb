# frozen_string_literal: true

module DiscourseWorkflows
  class Oauth2Connection
    LOCK_VALIDITY = 3.minutes.to_i
    REFRESH_SKEW = 1.minute.to_i

    def initialize(credential)
      raise Discourse::InvalidAccess unless credential.oauth2?
      @credential = credential
    end

    def connect
      synchronize do
        provider.validate_configuration(@credential)
        raise Oauth2Provider::Error.new("invalid_configuration") if @credential.errors.any?
        revoke_connection
        @credential.data = @credential.data.except("_oauth2", "_oauth2_attempt")
        @credential.save!
        acquire_connection
      end
    end

    def authorization_header(url)
      synchronize do
        connection = current_connection
        validate_api_url!(url, connection)
        if connection["expires_at"] && connection["expires_at"] <= Time.now.to_i + REFRESH_SKEW
          connection = acquire_connection
          validate_api_url!(url, connection)
        end
        "Bearer #{connection.fetch("access_token")}"
      end
    rescue Oauth2Provider::Error => error
      raise_node_error(error)
    end

    def refresh_authorization(url, rejected_header:)
      synchronize do
        connection = current_connection
        validate_api_url!(url, connection)
        if "Bearer #{connection.fetch("access_token")}" == rejected_header
          connection = acquire_connection
        end
        validate_api_url!(url, connection)
        "Bearer #{connection.fetch("access_token")}"
      end
    rescue Oauth2Provider::Error => error
      raise_node_error(error)
    end

    def reject_authorization(rejected_header:, raise_error: true)
      synchronize do
        connection = @credential.oauth_connection
        if "Bearer #{connection["access_token"]}" == rejected_header
          @credential.oauth_connection = connection.merge("status" => "reconnect_required")
          @credential.save!
        end
      end
      raise_node_error(Oauth2Provider::Revoked.new) if raise_error
    end

    def update(name:, data:)
      synchronize do
        original_data = @credential.data.deep_dup
        @credential.name = name
        @credential.merge_data(data) if data.present?
        if @credential.valid?
          if @credential.public_data !=
               Credential.public_data_for(@credential.credential_type, original_data)
            new_data = @credential.data.except("_oauth2", "_oauth2_attempt")
            @credential.data = original_data
            revoke_connection
            @credential.data = new_data
          end
          @credential.save
        end
        @credential
      end
    end

    def destroy
      synchronize do
        revoke_connection
        @credential.destroy!
      end
    end

    def expired_session?(response)
      provider.expired_session?(response)
    end

    private

    def synchronize
      DistributedMutex.synchronize(
        "discourse-workflows:oauth2:#{@credential.id}",
        validity: LOCK_VALIDITY,
      ) do
        @credential.reload
        yield
      end
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise Oauth2Provider::Revoked
    end

    def provider
      @credential.oauth_provider
    end

    def current_connection
      connection = @credential.oauth_connection
      if connection["status"] == "connected" && connection["access_token"].present? &&
           connection["grant_type"] == "client_credentials"
        connection
      else
        revoke_connection
        acquire_connection
      end
    end

    def validate_api_url!(url, connection)
      provider.validate_api_url!(url, connection)
    end

    def acquire_connection
      tokens = provider.authenticate
      # Retain the token for revocation if identity lookup fails.
      @credential.oauth_connection = token_data(tokens).merge("status" => "not_connected")
      @credential.save!
      identity = provider.identity(tokens)
      @credential.oauth_connection =
        @credential.oauth_connection.merge(identity).merge("status" => "connected")
      @credential.save!
      @credential.oauth_connection
    rescue Oauth2Provider::Revoked
      @credential.oauth_connection =
        @credential.oauth_connection.merge("status" => "reconnect_required")
      @credential.save!
      raise
    end

    def token_data(tokens)
      expires_in = Integer(tokens["expires_in"], exception: false)
      expires_in = provider.assumed_token_lifetime unless expires_in&.positive?
      {
        "access_token" => tokens.fetch("access_token"),
        "grant_type" => "client_credentials",
        "expires_at" => expires_in && expires_in.positive? ? Time.now.to_i + expires_in : nil,
        "last_refreshed_at" => Time.now.utc.iso8601,
      }.merge(provider.connection_data(tokens))
    end

    def revoke_connection
      token = @credential.oauth_connection["access_token"].presence
      provider.revoke(token) if token
    end

    def raise_node_error(error)
      message =
        if error.is_a?(Oauth2Provider::Revoked)
          I18n.t("discourse_workflows.oauth2.errors.credential_reconnect", name: @credential.name)
        else
          I18n.t(
            "discourse_workflows.oauth2.errors.credential_failed",
            name: @credential.name,
            message: error.message,
          )
        end
      raise NodeError, message
    end
  end
end
