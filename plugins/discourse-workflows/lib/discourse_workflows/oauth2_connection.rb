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
        revoke_connection(skip_unreadable: true)
        @credential.data = @credential.data.except("_oauth2")
        @credential.save!
        acquire_connection
      end
    end

    def authorization_header(url)
      synchronize do
        provider.validate_api_url!(url)
        connection = current_connection
        refresh_at =
          connection["refresh_at"] ||
            (connection["expires_at"] && connection["expires_at"] - REFRESH_SKEW)
        connection = acquire_connection if refresh_at && refresh_at <= Time.now.to_i
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
            new_data = @credential.data.except("_oauth2")
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
        revoke_connection(skip_unreadable: true)
        @credential.destroy!
      end
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

    def acquire_connection
      tokens = provider.authenticate
      @credential.oauth_connection = token_data(tokens).merge("status" => "connected")
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
      expires_at = Time.now.to_i + expires_in if expires_in&.positive?
      {
        "access_token" => tokens.fetch("access_token"),
        "grant_type" => "client_credentials",
        "expires_at" => expires_at,
        "refresh_at" => expires_at && expires_at - [REFRESH_SKEW, expires_in / 10].min,
        "last_refreshed_at" => Time.now.utc.iso8601,
      }
    end

    def revoke_connection(skip_unreadable: false)
      token =
        begin
          @credential.oauth_connection["access_token"].presence
        rescue ActiveSupport::MessageEncryptor::InvalidMessage
          raise unless skip_unreadable
          return
        end
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
