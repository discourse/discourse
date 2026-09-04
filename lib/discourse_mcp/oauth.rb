# frozen_string_literal: true

module DiscourseMcp
  module OAuth
    class ClientResolver
      MAX_METADATA_BYTES = 64.kilobytes
      METADATA_CACHE_TTL = 1.hour
      METADATA_REQUESTS_PER_MINUTE = 10
      METADATA_HOST_REQUESTS_PER_MINUTE = 30

      def self.resolve!(client_id, force: false, user:)
        existing = McpOauthClient.find_by(client_id: client_id)
        raise Discourse::InvalidAccess if existing&.blocked?
        if existing&.registration_type == "pre_registered" && existing.approved?
          return existing
        end
        if SiteSetting.mcp_oauth_client_id_metadata_policy == "disabled"
          raise Discourse::InvalidAccess
        end

        uri = URI.parse(client_id.to_s)
        raise Discourse::InvalidAccess if !valid_client_id_uri?(uri)
        if SiteSetting.mcp_oauth_client_id_metadata_policy ==
             "approved_domains" && !approved_domain?(uri.host)
          raise Discourse::InvalidAccess
        end
        if !force && existing&.approved? &&
             existing.metadata_expires_at&.future?
          return existing
        end

        enforce_rate_limits!(user, uri.host)
        metadata = fetch_metadata(uri)
        validate_metadata!(metadata, client_id)
        redirect_uris = metadata["redirect_uris"]
        metadata_hash =
          Digest::SHA256.hexdigest(JSON.generate(canonicalize(metadata)))
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
            last_seen_at: Time.zone.now
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

      def self.allowed_by_current_policy?(client)
        return client.approved? if client.registration_type == "pre_registered"
        return false if client.registration_type != "cimd" || !client.approved?

        case SiteSetting.mcp_oauth_client_id_metadata_policy
        when "any_domain"
          true
        when "approved_domains"
          approved_domain?(URI.parse(client.client_id).host)
        else
          false
        end
      rescue URI::InvalidURIError
        false
      end

      def self.revoke_disallowed_clients!
        McpOauthClient
          .where(registration_type: "cimd", trust_state: "approved")
          .in_batches do |clients|
            disallowed_ids =
              clients
                .select { |client| !allowed_by_current_policy?(client) }
                .map(&:id)
            next if disallowed_ids.empty?

            McpOauthClient.transaction do
              McpOauthAuthorization.require_consent!(client_ids: disallowed_ids)
              McpOauthClient.where(id: disallowed_ids).update_all(
                trust_state: "pending",
                updated_at: Time.zone.now
              )
            end
          end
      end

      def self.valid_client_id_uri?(uri)
        path_has_dot_segment =
          uri
            .path
            .split("/", -1)
            .any? { |segment| %w[. ..].include?(segment.gsub(/%2e/i, ".")) }
        uri.scheme == "https" && uri.host.present? && uri.userinfo.blank? &&
          uri.fragment.blank? && uri.path.present? && uri.path != "/" &&
          !path_has_dot_segment
      end
      private_class_method :valid_client_id_uri?

      def self.enforce_rate_limits!(user, host)
        normalized_host = host.downcase.delete_suffix(".")
        RateLimiter.new(
          user,
          "mcp-cimd-metadata",
          METADATA_REQUESTS_PER_MINUTE,
          1.minute,
          apply_limit_to_staff: true
        ).performed!
        RateLimiter.new(
          nil,
          "mcp-cimd-metadata-host-#{Digest::SHA256.hexdigest(normalized_host)}",
          METADATA_HOST_REQUESTS_PER_MINUTE,
          1.minute,
          apply_limit_to_staff: true
        ).performed!
      end
      private_class_method :enforce_rate_limits!

      def self.fetch_metadata(uri)
        body = +""
        status = nil
        content_type = nil
        FinalDestination
          .new(uri.to_s, validate_uri: true, max_redirects: 3, timeout: 5)
          .get do |response, chunk, _resolved_uri|
            status = response.code.to_i
            content_type = response["Content-Type"]
            body << chunk if chunk
            raise Discourse::InvalidAccess if body.bytesize > MAX_METADATA_BYTES
          end
        if status != 200 ||
             !content_type.to_s.match?(
               %r{\Aapplication/(?:[a-z0-9.+-]+\+)?json\b}i
             )
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
          metadata["client_id"] == client_id &&
            metadata["client_name"].is_a?(String) &&
            metadata["client_name"].bytesize <= 255 &&
            redirect_uris.is_a?(Array) && redirect_uris.present? &&
            redirect_uris.length <= 20 &&
            metadata.fetch("token_endpoint_auth_method", "none") == "none" &&
            !metadata.key?("client_secret") &&
            !metadata.key?("client_secret_expires_at") &&
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
        case SiteSetting.mcp_oauth_client_id_metadata_policy
        when "any_domain"
          "approved"
        when "approved_domains"
          approved_domain?(host) ? "approved" : "pending"
        else
          "pending"
        end
      end
      private_class_method :trust_state_for

      def self.approved_domain?(host)
        SiteSetting
          .mcp_oauth_client_id_metadata_domains
          .split("|")
          .any? { |domain| domain.casecmp?(host) }
      end
      private_class_method :approved_domain?
    end

    class AuthorizationGrant
      def self.grantable_scopes(user:, requested_scopes:)
        scopes = Array(requested_scopes).map(&:to_s).uniq
        if !scopes.include?(DiscourseMcp::INITIAL_SCOPE)
          raise Discourse::InvalidAccess
        end

        scopes & DiscourseMcp::Access.eligible_scopes(user)
      end

      def self.create!(user:, client:, redirect_uri:, requested_scopes:)
        if !SiteSetting.mcp_server_enabled ||
             !DiscourseMcp::Access.allowed?(user)
          raise Discourse::InvalidAccess
        end
        if !ClientResolver.allowed_by_current_policy?(client) ||
             !client.allows_redirect_uri?(redirect_uri)
          raise Discourse::InvalidAccess
        end

        scopes = grantable_scopes(user:, requested_scopes:)

        authorization =
          McpOauthAuthorization.find_or_initialize_by(
            user: user,
            client: client,
            revoked_at: nil
          )
        McpOauthAuthorization.transaction do
          authorization.lock! if authorization.persisted?
          if authorization.persisted?
            authorization
              .access_tokens
              .where(revoked_at: nil)
              .update_all(revoked_at: Time.zone.now)
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
            consented_at: Time.zone.now
          )
          authorization.save!
          authorization.scope_records.delete_all
          scopes.each do |scope|
            authorization.scope_records.create!(name: scope)
          end
        end
        authorization
      end
    end

    class TokenIssuer
      PKCE_VERIFIER_PATTERN = /\A[A-Za-z0-9\-._~]{43,128}\z/

      def self.exchange_code!(
        code:,
        client_id:,
        redirect_uri:,
        code_verifier:,
        resource:
      )
        code_record =
          McpOauthAuthorizationCode.find_by(
            code_hash: McpOauthAuthorizationCode.digest(code)
          )
        raise Discourse::InvalidAccess if code_record.blank?

        access_token = nil
        refresh_token = nil
        scopes = nil
        code_record.with_lock do
          if code_record.consumed_at.present? ||
               code_record.expires_at <= Time.zone.now
            raise Discourse::InvalidAccess
          end

          authorization = code_record.authorization
          if authorization.client.client_id != client_id
            raise Discourse::InvalidAccess
          end
          if code_record.redirect_uri != redirect_uri
            raise Discourse::InvalidAccess
          end
          if code_record.resource != resource ||
               resource != DiscourseMcp.resource_url
            raise Discourse::InvalidAccess
          end
          if !secure_compare_challenge(
               code_record.code_challenge,
               code_verifier
             )
            raise Discourse::InvalidAccess
          end
          validate_authorization!(
            authorization,
            scopes: code_record.scopes,
            grant_version: code_record.grant_version
          )

          scopes = code_record.scopes
          code_record.update!(consumed_at: Time.zone.now)
          access_token =
            McpOauthAccessToken.issue!(
              authorization: authorization,
              scopes: scopes
            )
          refresh_token, =
            McpOauthRefreshToken.issue!(
              authorization: authorization,
              scopes: scopes
            )
        end
        token_response(access_token, refresh_token, scopes)
      end

      def self.refresh!(
        refresh_token:,
        client_id:,
        resource:,
        requested_scopes: nil
      )
        record =
          McpOauthRefreshToken.find_by(
            token_hash: McpOauthRefreshToken.digest(refresh_token)
          )
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
          if authorization.client.client_id != client_id ||
               authorization.resource != resource
            raise Discourse::InvalidAccess
          end

          scopes =
            (
              if requested_scopes.present?
                Array(requested_scopes).map(&:to_s).uniq
              else
                record.scopes
              end
            )
          if !scopes.include?(DiscourseMcp::INITIAL_SCOPE) ||
               (scopes - record.scopes).present?
            raise Discourse::InvalidAccess
          end
          validate_authorization!(
            authorization,
            scopes: scopes,
            grant_version: record.grant_version
          )

          access_token =
            McpOauthAccessToken.issue!(
              authorization: authorization,
              scopes: scopes
            )
          new_refresh_token, =
            McpOauthRefreshToken.issue!(
              authorization: authorization,
              scopes: scopes,
              family_id: record.family_id,
              parent: record
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
          expires_in:
            SiteSetting.mcp_access_token_lifetime_minutes.minutes.to_i,
          refresh_token: refresh_token,
          scope: scopes.join(" ")
        }
      end
      private_class_method :token_response

      def self.validate_authorization!(authorization, scopes:, grant_version:)
        status =
          AuthorizationStatus.for(
            [authorization],
            scopes_by_authorization_id: {
              authorization.id => scopes
            }
          ).fetch(authorization.id)
        if status == "consent_required"
          authorization.update!(status: "consent_required")
        end
        raise Discourse::InvalidAccess if status != "active"
        if grant_version != authorization.grant_version
          raise Discourse::InvalidAccess
        end
        if (scopes - authorization.scopes).present?
          raise Discourse::InvalidAccess
        end
      end
      private_class_method :validate_authorization!

      def self.secure_compare_challenge(expected, verifier)
        return false if !PKCE_VERIFIER_PATTERN.match?(verifier.to_s)

        actual =
          Base64.urlsafe_encode64(
            Digest::SHA256.digest(verifier),
            padding: false
          )
        expected.bytesize == actual.bytesize &&
          ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      end
      private_class_method :secure_compare_challenge
    end
  end
end
