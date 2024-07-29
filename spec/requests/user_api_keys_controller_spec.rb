# frozen_string_literal: true

RSpec.describe UserApiKeysController do
  let :public_key do
    <<~TXT
    -----BEGIN PUBLIC KEY-----
    MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDh7BS7Ey8hfbNhlNAW/47pqT7w
    IhBz3UyBYzin8JurEQ2pY9jWWlY8CH147KyIZf1fpcsi7ZNxGHeDhVsbtUKZxnFV
    p16Op3CHLJnnJKKBMNdXMy0yDfCAHZtqxeBOTcCo1Vt/bHpIgiK5kmaekyXIaD0n
    w0z/BYpOgZ8QwnI5ZwIDAQAB
    -----END PUBLIC KEY-----
    TXT
  end

  let :private_key do
    <<~TXT
    -----BEGIN RSA PRIVATE KEY-----
    MIICWwIBAAKBgQDh7BS7Ey8hfbNhlNAW/47pqT7wIhBz3UyBYzin8JurEQ2pY9jW
    WlY8CH147KyIZf1fpcsi7ZNxGHeDhVsbtUKZxnFVp16Op3CHLJnnJKKBMNdXMy0y
    DfCAHZtqxeBOTcCo1Vt/bHpIgiK5kmaekyXIaD0nw0z/BYpOgZ8QwnI5ZwIDAQAB
    AoGAeHesbjzCivc+KbBybXEEQbBPsThY0Y+VdgD0ewif2U4UnNhzDYnKJeTZExwQ
    vAK2YsRDV3KbhljnkagQduvmgJyCKuV/CxZvbJddwyIs3+U2D4XysQp3e1YZ7ROr
    YlOIoekHCx1CNm6A4iImqGxB0aJ7Owdk3+QSIaMtGQWaPTECQQDz2UjJ+bomguNs
    zdcv3ZP7W3U5RG+TpInSHiJXpt2JdNGfHItozGJCxfzDhuKHK5Cb23bgldkvB9Xc
    p/tngTtNAkEA7S4cqUezA82xS7aYPehpRkKEmqzMwR3e9WeL7nZ2cdjZAHgXe49l
    3mBhidEyRmtPqbXo1Xix8LDuqik0IdnlgwJAQeYTnLnHS8cNjQbnw4C/ECu8Nzi+
    aokJ0eXg5A0tS4ttZvGA31Z0q5Tz5SdbqqnkT6p0qub0JZiZfCNNdsBe9QJAaGT5
    fJDwfGYW+YpfLDCV1bUFhMc2QHITZtSyxL0jmSynJwu02k/duKmXhP+tL02gfMRy
    vTMorxZRllgYeCXeXQJAEGRXR8/26jwqPtKKJzC7i9BuOYEagqj0nLG2YYfffCMc
    d3JGCf7DMaUlaUE8bJ08PtHRJFSGkNfDJLhLKSjpbw==
    -----END RSA PRIVATE KEY-----
    TXT
  end

  let :args do
    {
      scopes: "read",
      client_id: "x" * 32,
      auth_redirect: "http://over.the/rainbow",
      application_name: "foo",
      public_key: public_key,
      nonce: SecureRandom.hex,
    }
  end

  describe "#new" do
    it "supports a head request cleanly" do
      head "/user-api-key/new"
      expect(response.status).to eq(200)
      expect(response.headers["Auth-Api-Version"]).to eq("4")
    end
  end

  describe "#create" do
    it "does not allow anon" do
      post "/user-api-key.json", params: args
      expect(response.status).to eq(403)
    end

    it "refuses to redirect to disallowed place" do
      sign_in(Fabricate(:user))
      post "/user-api-key.json", params: args
      expect(response.status).to eq(403)
    end

    it "will allow tokens for staff without TL" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]

      user = Fabricate(:user, trust_level: TrustLevel[1], moderator: true)

      sign_in(user)

      post "/user-api-key.json", params: args
      expect(response.status).to eq(302)
    end

    it "will not create token unless TL is met" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]

      user = Fabricate(:user, trust_level: TrustLevel[1])
      sign_in(user)

      post "/user-api-key.json", params: args
      expect(response.status).to eq(403)
    end

    it "will deny access if requesting more rights than allowed" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      SiteSetting.allow_user_api_key_scopes = "write"

      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      post "/user-api-key.json", params: args
      expect(response.status).to eq(403)
    end

    it "allows for a revoke with no id" do
      key = Fabricate(:readonly_user_api_key)
      post "/user-api-key/revoke.json", headers: { HTTP_USER_API_KEY: key.key }

      expect(response.status).to eq(200)
      key.reload
      expect(key.revoked_at).not_to eq(nil)
    end

    it "will not allow readonly api keys to revoke others" do
      key1 = Fabricate(:readonly_user_api_key)
      key2 = Fabricate(:readonly_user_api_key)

      post "/user-api-key/revoke.json",
           params: {
             id: key2.id,
           },
           headers: {
             HTTP_USER_API_KEY: key1.key,
           }

      expect(response.status).to eq(403)
    end

    it "will allow readonly api keys to revoke self" do
      key = Fabricate(:readonly_user_api_key)
      post "/user-api-key/revoke.json",
           params: {
             id: key.id,
           },
           headers: {
             HTTP_USER_API_KEY: key.key,
           }

      expect(response.status).to eq(200)
      key.reload
      expect(key.revoked_at).not_to eq(nil)
    end

    it "will not allow revoking another users key" do
      key = Fabricate(:readonly_user_api_key)
      acting_user = Fabricate(:user)
      sign_in(acting_user)

      post "/user-api-key/revoke.json", params: { id: key.id }

      expect(response.status).to eq(403)
      key.reload
      expect(key.revoked_at).to eq(nil)
    end

    it "will not return p access if not yet configured" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]

      args[:scopes] = "push,read"
      args[:push_url] = "https://push.it/here"

      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      post "/user-api-key.json", params: args
      expect(response.status).to eq(302)

      uri = URI.parse(response.redirect_url)

      query = uri.query
      payload = query.split("payload=")[1]
      encrypted = Base64.decode64(CGI.unescape(payload))

      key = OpenSSL::PKey::RSA.new(private_key)

      parsed = JSON.parse(key.private_decrypt(encrypted))

      expect(parsed["nonce"]).to eq(args[:nonce])
      expect(parsed["push"]).to eq(false)
      expect(parsed["api"]).to eq(4)

      key = user.user_api_keys.first
      expect(key.scopes.map(&:name)).to include("push")
      expect(key.push_url).to eq("https://push.it/here")
    end

    it "will redirect correctly with valid token" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      SiteSetting.allowed_user_api_push_urls = "https://push.it/here"

      args[:scopes] = "push,notifications,message_bus,session_info,one_time_password"
      args[:push_url] = "https://push.it/here"

      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      post "/user-api-key.json", params: args
      expect(response.status).to eq(302)

      uri = URI.parse(response.redirect_url)

      query = uri.query
      payload = query.split("payload=")[1]
      encrypted = Base64.decode64(CGI.unescape(payload))

      key = OpenSSL::PKey::RSA.new(private_key)

      parsed = JSON.parse(key.private_decrypt(encrypted))

      expect(parsed["nonce"]).to eq(args[:nonce])
      expect(parsed["push"]).to eq(true)

      api_key = UserApiKey.with_key(parsed["key"]).first

      expect(api_key.user_id).to eq(user.id)
      expect(api_key.scopes.map(&:name).sort).to eq(
        %w[push message_bus notifications session_info one_time_password].sort,
      )
      expect(api_key.push_url).to eq("https://push.it/here")

      uri.query = ""
      expect(uri.to_s).to eq(args[:auth_redirect] + "?")

      # should overwrite if needed
      args["access"] = "pr"
      post "/user-api-key.json", params: args

      expect(response.status).to eq(302)

      one_time_password = query.split("oneTimePassword=")[1]
      encrypted_otp = Base64.decode64(CGI.unescape(one_time_password))

      parsed_otp = key.private_decrypt(encrypted_otp)
      redis_key = "otp_#{parsed_otp}"

      expect(Discourse.redis.get(redis_key)).to eq(user.username)
    end

    it "will just show the payload if no redirect" do
      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      args.delete(:auth_redirect)

      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      post "/user-api-key", params: args
      expect(response.status).not_to eq(302)
      payload = Nokogiri.HTML5(response.body).at("code").content
      encrypted = Base64.decode64(payload)
      key = OpenSSL::PKey::RSA.new(private_key)
      parsed = JSON.parse(key.private_decrypt(encrypted))
      api_key = UserApiKey.with_key(parsed["key"]).first
      expect(api_key.user_id).to eq(user.id)
    end

    it "will just show the JSON payload if no redirect" do
      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      args.delete(:auth_redirect)

      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      post "/user-api-key.json", params: args
      expect(response.status).not_to eq(302)
      payload = response.parsed_body["payload"]
      encrypted = Base64.decode64(payload)
      key = OpenSSL::PKey::RSA.new(private_key)
      parsed = JSON.parse(key.private_decrypt(encrypted))
      api_key = UserApiKey.with_key(parsed["key"]).first
      expect(api_key.user_id).to eq(user.id)
    end

    it "will allow redirect to wildcard urls" do
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect] + "/*"
      args[:auth_redirect] = args[:auth_redirect] + "/bluebirds/fly"

      sign_in(Fabricate(:user, refresh_auto_groups: true))

      post "/user-api-key.json", params: args
      expect(response.status).to eq(302)
    end

    it "will keep query_params added in auth_redirect" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect] + "/*"

      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      query_str = "/?param1=val1"
      args[:auth_redirect] = args[:auth_redirect] + query_str

      post "/user-api-key.json", params: args
      expect(response.status).to eq(302)

      uri = URI.parse(response.redirect_url)
      expect(uri.to_s).to include(query_str)
    end

    it "revokes API key when client_id used by another user" do
      user1 = Fabricate(:trust_level_0)
      user2 = Fabricate(:trust_level_0)
      key = Fabricate(:user_api_key, user: user1)

      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      SiteSetting.allowed_user_api_push_urls = "https://push.it/here"
      args[:client_id] = key.client_id
      args[:scopes] = "push,notifications,message_bus,session_info,one_time_password"
      args[:push_url] = "https://push.it/here"

      sign_in(user2)

      post "/user-api-key.json", params: args

      expect(response.status).to eq(302)
      expect(UserApiKey.exists?(key.id)).to eq(false)
    end

    context "with a registered client" do
      let!(:fixed_args) { args }
      let!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
      let!(:client) do
        Fabricate(
          :user_api_key_client,
          client_id: fixed_args[:client_id],
          application_name: fixed_args[:application_name],
          public_key: public_key,
          auth_redirect: fixed_args[:auth_redirect],
        )
      end

      before { sign_in(user) }

      it "does not require allowed_user_api_auth_redirects to contain registered auth_redirect" do
        post "/user-api-key.json", params: fixed_args
        expect(response.status).to eq(302)
      end

      it "does not require application_name or public_key params" do
        post "/user-api-key.json", params: fixed_args.except(:application_name, :public_key)
        expect(response.status).to eq(302)
      end
    end
  end

  describe "#create-one-time-password" do
    let :otp_args do
      {
        auth_redirect: "http://somewhere.over.the/rainbow",
        application_name: "foo",
        public_key: public_key,
      }
    end

    it "does not allow anon" do
      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(403)
    end

    it "refuses to redirect to disallowed place" do
      sign_in(Fabricate(:user))
      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(403)
    end

    it "will allow one-time-password for staff without TL" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]

      user = Fabricate(:user, trust_level: TrustLevel[1], moderator: true)

      sign_in(user)

      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(302)
    end

    it "will not allow one-time-password unless TL is met" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]

      user = Fabricate(:user, trust_level: TrustLevel[1])
      sign_in(user)

      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(403)
    end

    it "will not allow one-time-password if one_time_password scope is disallowed" do
      SiteSetting.allow_user_api_key_scopes = "read|write"
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      user = Fabricate(:user)
      sign_in(user)

      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(403)
    end

    it "will return one-time-password when args are valid" do
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      user = Fabricate(:user, refresh_auto_groups: true)
      sign_in(user)

      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(302)

      uri = URI.parse(response.redirect_url)

      query = uri.query
      payload = query.split("oneTimePassword=")[1]
      encrypted = Base64.decode64(CGI.unescape(payload))
      key = OpenSSL::PKey::RSA.new(private_key)

      parsed = key.private_decrypt(encrypted)

      expect(Discourse.redis.get("otp_#{parsed}")).to eq(user.username)
    end
  end
end
