# frozen_string_literal: true

module Voice
  # Builds the RTCPeerConnection ICE configuration delivered to clients on
  # room join. TURN servers come from two independent lists: voice_turn_servers
  # uses the static username/password pair, while voice_turn_secret_servers
  # gets credentials minted per user with the TURN REST API scheme (coturn's
  # use-auth-secret), so both kinds of deployment can coexist.
  module IceConfig
    # coturn only checks the expiry embedded in the username when a new
    # allocation is created, so this needs to outlast credential mint →
    # peer creation gaps (late joiners, ICE restarts), not the call itself.
    EPHEMERAL_CREDENTIAL_TTL = 12.hours

    def self.payload(user)
      { servers: servers(user), transport_policy: transport_policy }
    end

    def self.servers(user)
      stun_urls.map { |url| { urls: url } } + static_turn_servers + ephemeral_turn_servers(user)
    end

    def self.static_turn_servers
      username = SiteSetting.voice_turn_username
      credential = SiteSetting.voice_turn_credential

      static_turn_urls.map do |url|
        server = { urls: url }
        server[:username] = username if username.present?
        server[:credential] = credential if credential.present?
        server
      end
    end

    def self.ephemeral_turn_servers(user)
      return [] if ephemeral_turn_urls.empty? || SiteSetting.voice_turn_secret.blank?

      username, credential = ephemeral_credentials(user)
      ephemeral_turn_urls.map { |url| { urls: url, username: username, credential: credential } }
    end

    # Expiry-first username and HMAC-SHA1 credential are dictated by the
    # TURN REST API spec. coturn drops the numeric expiry before applying
    # user-quota, so the hostname:user_id remainder is the quota identity —
    # without it, same-numbered users on different sites sharing a coturn
    # realm would share quota. It also attributes relay traffic to a site
    # in TURN server logs.
    def self.ephemeral_credentials(user)
      username =
        "#{EPHEMERAL_CREDENTIAL_TTL.from_now.to_i}:#{Discourse.current_hostname}:#{user.id}"
      digest = OpenSSL::HMAC.digest("SHA1", SiteSetting.voice_turn_secret, username)
      [username, Base64.strict_encode64(digest)]
    end

    # A TURN-only setup with static credentials keeps the historical
    # relay-only behavior. Secret-authenticated TURN keeps the policy at
    # "all" even without STUN: server-reflexive candidates come from the
    # (authenticated) TURN allocation, so direct connections still work.
    def self.transport_policy
      ephemeral_active = ephemeral_turn_urls.any? && SiteSetting.voice_turn_secret.present?

      if stun_urls.empty? && !ephemeral_active && static_turn_urls.any?
        "relay"
      else
        "all"
      end
    end

    def self.stun_urls
      parse_url_list(SiteSetting.voice_stun_servers)
    end

    def self.static_turn_urls
      parse_url_list(SiteSetting.voice_turn_servers)
    end

    def self.ephemeral_turn_urls
      parse_url_list(SiteSetting.voice_turn_secret_servers)
    end

    def self.parse_url_list(setting)
      setting.to_s.split("|").map(&:strip).reject(&:empty?)
    end
  end
end
