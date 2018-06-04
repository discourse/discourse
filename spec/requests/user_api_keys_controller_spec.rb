require 'rails_helper'

describe UserApiKeysController do

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
      scopes: 'read',
      client_id: "x" * 32,
      auth_redirect: 'http://over.the/rainbow',
      application_name: 'foo',
      public_key: public_key,
      nonce: SecureRandom.hex
    }
  end

  context 'new' do
    it "supports a head request cleanly" do
      head "/user-api-key/new"
      expect(response.status).to eq(200)
      expect(response.headers["Auth-Api-Version"]).to eq("2")
    end
  end

  context 'create' do

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
      SiteSetting.min_trust_level_for_user_api_key = 2
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]

      user = Fabricate(:user, trust_level: 1, moderator: true)

      sign_in(user)

      post "/user-api-key.json", params: args
      expect(response.status).to eq(302)
    end

    it "will not create token unless TL is met" do
      SiteSetting.min_trust_level_for_user_api_key = 2
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]

      user = Fabricate(:user, trust_level: 1)
      sign_in(user)

      post "/user-api-key.json", params: args
      expect(response.status).to eq(403)
    end

    it "will deny access if requesting more rights than allowed" do
      SiteSetting.min_trust_level_for_user_api_key = 0
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      SiteSetting.allow_user_api_key_scopes = "write"

      user = Fabricate(:user, trust_level: 0)
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
        params: { id: key2.id },
        headers: { HTTP_USER_API_KEY: key1.key }

      expect(response.status).to eq(403)
    end

    it "will allow readonly api keys to revoke self" do
      key = Fabricate(:readonly_user_api_key)
      post "/user-api-key/revoke.json",
        params: { id: key.id },
        headers: { HTTP_USER_API_KEY: key.key }

      expect(response.status).to eq(200)
      key.reload
      expect(key.revoked_at).not_to eq(nil)
    end

    it "will not return p access if not yet configured" do
      SiteSetting.min_trust_level_for_user_api_key = 0
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]

      args[:scopes] = "push,read"
      args[:push_url] = "https://push.it/here"

      user = Fabricate(:user, trust_level: 0)
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
      expect(parsed["api"]).to eq(2)

      key = user.user_api_keys.first
      expect(key.scopes).to include("push")
      expect(key.push_url).to eq("https://push.it/here")
    end

    it "will redirect correctly with valid token" do
      SiteSetting.min_trust_level_for_user_api_key = 0
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      SiteSetting.allowed_user_api_push_urls = "https://push.it/here"

      args[:scopes] = "push,notifications,message_bus,session_info"
      args[:push_url] = "https://push.it/here"

      user = Fabricate(:user, trust_level: 0)
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

      api_key = UserApiKey.find_by(key: parsed["key"])

      expect(api_key.user_id).to eq(user.id)
      expect(api_key.scopes.sort).to eq(["push", "message_bus", "notifications", "session_info"].sort)
      expect(api_key.push_url).to eq("https://push.it/here")

      uri.query = ""
      expect(uri.to_s).to eq(args[:auth_redirect] + "?")

      # should overwrite if needed
      args["access"] = "pr"
      post "/user-api-key.json", params: args

      expect(response.status).to eq(302)
    end
  end
end
