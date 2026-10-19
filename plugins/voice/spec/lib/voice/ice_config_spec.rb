# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::IceConfig do
  fab!(:user)

  describe ".payload" do
    it "builds one entry per STUN url, ignoring blank segments" do
      SiteSetting.voice_stun_servers = "stun:stun.example.com:3478| |stun:stun2.example.com:19302"

      payload = described_class.payload(user)

      expect(payload[:servers]).to contain_exactly(
        { urls: "stun:stun.example.com:3478" },
        { urls: "stun:stun2.example.com:19302" },
      )
    end

    it "attaches the static username and credential to every static TURN url" do
      SiteSetting.voice_stun_servers = ""
      SiteSetting.voice_turn_servers = "turn:turn.example.com:3478|turns:turn.example.com:5349"
      SiteSetting.voice_turn_username = "static-user"
      SiteSetting.voice_turn_credential = "static-pass"

      payload = described_class.payload(user)

      expect(payload[:servers]).to contain_exactly(
        { urls: "turn:turn.example.com:3478", username: "static-user", credential: "static-pass" },
        { urls: "turns:turn.example.com:5349", username: "static-user", credential: "static-pass" },
      )
    end

    it "omits the username and credential keys when the static credentials are blank" do
      SiteSetting.voice_stun_servers = ""
      SiteSetting.voice_turn_servers = "turn:turn.example.com:3478"

      payload = described_class.payload(user)

      expect(payload[:servers]).to contain_exactly({ urls: "turn:turn.example.com:3478" })
    end

    it "mints ephemeral HMAC credentials scoped to the site and user for secret TURN servers" do
      SiteSetting.voice_stun_servers = ""
      SiteSetting.voice_turn_secret = "coturn-shared-secret"
      SiteSetting.voice_turn_secret_servers = "turn:turn.example.com:3478"

      freeze_time do
        payload = described_class.payload(user)
        server = payload[:servers].first

        expected_username =
          "#{(Time.zone.now + described_class::EPHEMERAL_CREDENTIAL_TTL).to_i}:#{Discourse.current_hostname}:#{user.id}"
        expected_credential =
          Base64.strict_encode64(
            OpenSSL::HMAC.digest("SHA1", "coturn-shared-secret", expected_username),
          )

        expect(server).to eq(
          urls: "turn:turn.example.com:3478",
          username: expected_username,
          credential: expected_credential,
        )
      end
    end

    it "separates quota identities of same-numbered users on different sites" do
      SiteSetting.voice_stun_servers = ""
      SiteSetting.voice_turn_secret = "coturn-shared-secret"
      SiteSetting.voice_turn_secret_servers = "turn:coturn.example.com:3478"

      freeze_time do
        username = described_class.payload(user)[:servers].first[:username]

        SiteSetting.force_hostname = "other-site.example.com"
        other_site_username = described_class.payload(user)[:servers].first[:username]

        expect(username).not_to eq(other_site_username)
        expect(other_site_username).to eq(
          "#{(Time.zone.now + described_class::EPHEMERAL_CREDENTIAL_TTL).to_i}:other-site.example.com:#{user.id}",
        )
      end
    end

    it "keeps static and secret TURN servers side by side with their own credentials" do
      SiteSetting.voice_stun_servers = ""
      SiteSetting.voice_turn_servers = "turn:third-party.example.com:3478"
      SiteSetting.voice_turn_username = "static-user"
      SiteSetting.voice_turn_credential = "static-pass"
      SiteSetting.voice_turn_secret = "coturn-shared-secret"
      SiteSetting.voice_turn_secret_servers = "turn:coturn.example.com:3478"

      servers = described_class.payload(user)[:servers]
      static_server = servers.find { |server| server[:urls].include?("third-party") }
      secret_server = servers.find { |server| server[:urls].include?("coturn") }

      expect(servers.size).to eq(2)
      expect(static_server[:username]).to eq("static-user")
      expect(static_server[:credential]).to eq("static-pass")
      expect(secret_server[:username]).to end_with(":#{Discourse.current_hostname}:#{user.id}")
      expect(secret_server[:credential]).to eq(
        Base64.strict_encode64(
          OpenSSL::HMAC.digest("SHA1", "coturn-shared-secret", secret_server[:username]),
        ),
      )
    end

    it "skips secret TURN servers when the shared secret has been blanked" do
      SiteSetting.voice_stun_servers = ""
      SiteSetting.voice_turn_secret = "coturn-shared-secret"
      SiteSetting.voice_turn_secret_servers = "turn:coturn.example.com:3478"
      SiteSetting.voice_turn_secret = ""

      expect(described_class.payload(user)[:servers]).to eq([])
    end

    it "forces relay when only static TURN servers are configured" do
      SiteSetting.voice_stun_servers = ""
      SiteSetting.voice_turn_servers = "turn:turn.example.com:3478"
      SiteSetting.voice_turn_credential = "static-pass"

      expect(described_class.payload(user)[:transport_policy]).to eq("relay")
    end

    it "keeps policy 'all' when secret TURN servers are active, even without STUN" do
      SiteSetting.voice_stun_servers = ""
      SiteSetting.voice_turn_secret = "coturn-shared-secret"
      SiteSetting.voice_turn_secret_servers = "turn:coturn.example.com:3478"

      expect(described_class.payload(user)[:transport_policy]).to eq("all")
    end

    it "keeps policy 'all' when STUN servers are configured alongside static TURN" do
      SiteSetting.voice_stun_servers = "stun:stun.example.com:3478"
      SiteSetting.voice_turn_servers = "turn:turn.example.com:3478"
      SiteSetting.voice_turn_credential = "static-pass"

      expect(described_class.payload(user)[:transport_policy]).to eq("all")
    end

    it "keeps policy 'all' when no TURN servers are configured" do
      SiteSetting.voice_stun_servers = ""

      expect(described_class.payload(user)[:transport_policy]).to eq("all")
    end
  end
end
