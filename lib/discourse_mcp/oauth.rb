# frozen_string_literal: true

module DiscourseMcp
  module OAuth
    class ClientResolver
      MAX_METADATA_BYTES = 64.kilobytes
      METADATA_CACHE_TTL = 1.hour

      def self.resolve!(client_id, force: false)
        existing = McpOauthClient.find_by(client_id: client_id)
        raise Discourse::InvalidAccess if existing&.blocked?
        return existing if existing&.registration_type == "pre_registered" && existing.approved?
        return existing if !force && existing&.approved? && existing.metadata_expires_at&.future?
        if SiteSetting.mcp_oauth_client_trust_policy == "pre_registered"
          raise Discourse::InvalidAccess
        end

        uri = URI.parse(client_id)
        if uri.scheme != "https" || uri.host.blank? || uri.userinfo.present? ||
             uri.fragment.present? || uri.path.blank? || uri.path == "/"
          raise Discourse::InvalidAccess
        end

        metadata = fetch_metadata(uri)
        validate_metadata!(metadata, client_id)
        redirect_uris = metadata["redirect_uris"]
        metadata_hash = Digest::SHA256.hexdigest(JSON.generate(canonicalize(metadata)))
        trust_state = trust_state_for(uri.host)
        client = existing || McpOauthClient.new(client_id: client_id)
        previous_hash = client.metadata_hash

        McpOauthClient.transaction do
          client.assign_attributes(
            name: metadata["client_name"].presence || uri.host,
            registration_type: "cimd",
            trust_state: trust_state,
            metadata_uri: client_id,
            metadata_hash: metadata_hash,
            metadata_expires_at: METADATA_CACHE_TTL.from_now,
            metadata: metadata,
            redirect_uris: redirect_uris,
            last_seen_at: Time.zone.now,
          )
          client.save!
          if previous_hash.present? && previous_hash != metadata_hash
            client.authorizations.active.find_each do |authorization|
              authorization.update!(status: "consent_required")
              authorization
                .access_tokens
                .where(revoked_at: nil)
                .update_all(revoked_at: Time.zone.now)
              authorization
                .refresh_tokens
                .where(revoked_at: nil)
                .update_all(revoked_at: Time.zone.now)
            end
          end
        end
        raise Discourse::InvalidAccess if !client.approved?
        client
      rescue URI::InvalidURIError,
             JSON::ParserError,
             FinalDestination::SSRFError,
             SocketError,
             Net::OpenTimeout,
             Net::ReadTimeout
        raise Discourse::InvalidAccess
      end

      def self.fetch_metadata(uri)
        body = +""
        status = nil
        content_type = nil
        FinalDestination
          .new(uri.to_s, validate_uri: true, max_redirects: 3, timeout: 5)
          .get do |response, chunk, _resolved_uri|
            status = response.code.to_i
            content_type = response["Content-Type"]
            body << chunk
            raise Discourse::InvalidAccess if body.bytesize > MAX_METADATA_BYTES
          end
        if status != 200 || !content_type.to_s.match?(%r{\Aapplication/(?:[a-z0-9.+-]+\+)?json\b}i)
          raise Discourse::InvalidAccess
        end

        parsed = JSON.parse(body)
        raise Discourse::InvalidAccess if !parsed.is_a?(Hash)
        parsed
      end
      private_class_method :fetch_metadata

      def self.validate_metadata!(metadata, client_id)
        redirect_uris = metadata["redirect_uris"]
        valid =
          metadata["client_id"] == client_id && metadata["client_name"].is_a?(String) &&
            metadata["client_name"].bytesize <= 255 && redirect_uris.is_a?(Array) &&
            redirect_uris.present? && redirect_uris.length <= 20 &&
            redirect_uris.all? do |value|
              value.is_a?(String) && McpOauthClient.valid_redirect_uri?(value)
            end
        raise Discourse::InvalidAccess if !valid
      end
      private_class_method :validate_metadata!

      def self.canonicalize(value)
        case value
        when Hash
          value.keys.sort.to_h { |key| [key, canonicalize(value[key])] }
        when Array
          value.map { |item| canonicalize(item) }
        else
          value
        end
      end
      private_class_method :canonicalize

      def self.trust_state_for(host)
        case SiteSetting.mcp_oauth_client_trust_policy
        when "any_cimd"
          "approved"
        when "approved_domains"
          if SiteSetting.mcp_oauth_approved_domains_map.include?(host.downcase)
            "approved"
          else
            "pending"
          end
        else
          "pending"
        end
      end
      private_class_method :trust_state_for
    end

    class AuthorizationGrant
      def self.create!(user:, client:, profile:, redirect_uri:, requested_scopes:)
        raise Discourse::InvalidAccess if !profile.available? || !profile.user_allowed?(user)
        if !client.approved? || !client.redirect_uris.include?(redirect_uri)
          raise Discourse::InvalidAccess
        end

        scopes = Array(requested_scopes).map(&:to_s).uniq
        if scopes.blank? || (scopes - profile.allowed_scopes).present?
          raise Discourse::InvalidAccess
        end

        authorization =
          McpOauthAuthorization.find_or_initialize_by(
            user: user,
            client: client,
            profile: profile,
            revoked_at: nil,
          )
        McpOauthAuthorization.transaction do
          authorization.lock! if authorization.persisted?
          if authorization.persisted?
            authorization.access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.zone.now)
            authorization
              .refresh_tokens
              .where(revoked_at: nil)
              .update_all(revoked_at: Time.zone.now)
            authorization.grant_version += 1
          end
          authorization.assign_attributes(
            resource: DiscourseMcp.resource_url,
            status: "active",
            client_metadata_hash: client.metadata_hash,
            consent_revision: profile.consent_revision,
            consented_at: Time.zone.now,
          )
          authorization.save!
          authorization.scope_records.delete_all
          scopes.each { |scope| authorization.scope_records.create!(name: scope) }
        end
        authorization
      end
    end

    class TokenIssuer
      PKCE_VERIFIER_PATTERN = /\A[A-Za-z0-9\-._~]{43,128}\z/

      def self.exchange_code!(code:, client_id:, redirect_uri:, code_verifier:, resource:)
        code_record =
          McpOauthAuthorizationCode.find_by(code_hash: McpOauthAuthorizationCode.digest(code))
        raise Discourse::InvalidAccess if code_record.blank?

        access_token = nil
        refresh_token = nil
        scopes = nil
        code_record.with_lock do
          if code_record.consumed_at.present? || code_record.expires_at <= Time.zone.now
            raise Discourse::InvalidAccess
          end

          authorization = code_record.authorization
          raise Discourse::InvalidAccess if authorization.client.client_id != client_id
          raise Discourse::InvalidAccess if code_record.redirect_uri != redirect_uri
          if code_record.resource != resource || resource != DiscourseMcp.resource_url
            raise Discourse::InvalidAccess
          end
          if !secure_compare_challenge(code_record.code_challenge, code_verifier)
            raise Discourse::InvalidAccess
          end
          validate_authorization!(
            authorization,
            scopes: code_record.scopes,
            grant_version: code_record.grant_version,
          )

          scopes = code_record.scopes
          code_record.update!(consumed_at: Time.zone.now)
          access_token = McpOauthAccessToken.issue!(authorization: authorization, scopes: scopes)
          refresh_token, = McpOauthRefreshToken.issue!(authorization: authorization, scopes: scopes)
        end
        token_response(access_token, refresh_token, scopes)
      end

      def self.refresh!(refresh_token:, client_id:, resource:, requested_scopes: nil)
        record =
          McpOauthRefreshToken.find_by(token_hash: McpOauthRefreshToken.digest(refresh_token))
        raise Discourse::InvalidAccess if record.blank?

        replayed = false
        access_token = nil
        new_refresh_token = nil
        scopes = nil
        record.with_lock do
          if record.consumed_at.present?
            record.revoke_family!
            replayed = true
            next
          end

          if record.revoked_at.present? || record.expires_at <= Time.zone.now
            raise Discourse::InvalidAccess
          end
          authorization = record.authorization
          if authorization.client.client_id != client_id || authorization.resource != resource
            raise Discourse::InvalidAccess
          end

          scopes =
            requested_scopes.present? ? Array(requested_scopes).map(&:to_s).uniq : record.scopes
          raise Discourse::InvalidAccess if (scopes - record.scopes).present?
          validate_authorization!(
            authorization,
            scopes: scopes,
            grant_version: record.grant_version,
          )

          access_token = McpOauthAccessToken.issue!(authorization: authorization, scopes: scopes)
          new_refresh_token, =
            McpOauthRefreshToken.issue!(
              authorization: authorization,
              scopes: scopes,
              family_id: record.family_id,
              parent: record,
            )
        end
        raise Discourse::InvalidAccess if replayed

        token_response(access_token, new_refresh_token, scopes)
      end

      def self.revoke!(token)
        digest = McpOauthAccessToken.digest(token)
        access = McpOauthAccessToken.find_by(token_hash: digest)
        return access.update!(revoked_at: Time.zone.now) if access

        refresh = McpOauthRefreshToken.find_by(token_hash: digest)
        refresh&.revoke_family!
      end

      def self.token_response(access_token, refresh_token, scopes)
        {
          access_token: access_token,
          token_type: "Bearer",
          expires_in: SiteSetting.mcp_access_token_lifetime_minutes.minutes.to_i,
          refresh_token: refresh_token,
          scope: scopes.join(" "),
        }
      end
      private_class_method :token_response

      def self.validate_authorization!(authorization, scopes:, grant_version:)
        raise Discourse::InvalidAccess if !authorization.active?
        raise Discourse::InvalidAccess if !authorization.client.approved?
        if authorization.client_metadata_hash != authorization.client.metadata_hash
          raise Discourse::InvalidAccess
        end
        raise Discourse::InvalidAccess if !authorization.profile.available?
        raise Discourse::InvalidAccess if !authorization.profile.user_allowed?(authorization.user)
        raise Discourse::InvalidAccess if grant_version != authorization.grant_version
        raise Discourse::InvalidAccess if (scopes - authorization.scopes).present?
        raise Discourse::InvalidAccess if (scopes - authorization.profile.allowed_scopes).present?
        if authorization.consent_revision < authorization.profile.consent_revision
          authorization.update!(status: "consent_required")
          raise Discourse::InvalidAccess
        end
      end
      private_class_method :validate_authorization!

      def self.secure_compare_challenge(expected, verifier)
        return false if !PKCE_VERIFIER_PATTERN.match?(verifier.to_s)

        actual = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
        expected.bytesize == actual.bytesize &&
          ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      end
      private_class_method :secure_compare_challenge
    end
  end
end
