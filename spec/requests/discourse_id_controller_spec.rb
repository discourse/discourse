# frozen_string_literal: true

RSpec.describe Users::DiscourseIdController do
  let(:client_id) { SiteSetting.discourse_id_client_id }
  let(:hashed_secret) { Digest::SHA256.hexdigest(SiteSetting.discourse_id_client_secret) }
  let(:identifier) { SecureRandom.hex }
  let(:provider_name) { "discourse_id" }

  let!(:user) { Fabricate(:user) }
  let!(:user_associated_account) do
    Fabricate(:user_associated_account, user:, provider_name:, provider_uid: identifier)
  end

  before do
    SiteSetting.enable_discourse_id = true
    SiteSetting.discourse_id_client_id = SecureRandom.hex
    SiteSetting.discourse_id_client_secret = SecureRandom.hex
  end

  describe "#revoke" do
    context "with valid parameters" do
      it "revokes all auth tokens for the user" do
        UserAuthToken.generate!(user_id: user.id)
        UserAuthToken.generate!(user_id: user.id)

        expect(UserAuthToken.where(user_id: user.id).count).to eq(2)

        timestamp = Time.now.to_i
        signature =
          OpenSSL::HMAC.hexdigest(
            "sha256",
            hashed_secret,
            "#{client_id}:#{identifier}:#{timestamp}",
          )

        post "/auth/discourse_id/revoke.json", params: { signature:, identifier:, timestamp: }

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq(true)

        expect(UserAuthToken.where(user_id: user.id).count).to eq(0)
      end
    end

    context "with invalid parameters" do
      it "returns 400 when signature is invalid" do
        timestamp = Time.now.to_i
        signature = SecureRandom.hex

        post "/auth/discourse_id/revoke.json", params: { signature:, identifier:, timestamp: }

        expect(response.status).to eq(400)
        expect(response.parsed_body["error"]).to match(/Signature is invalid/)

        post "/auth/discourse_id/revoke.json", params: { signature:, identifier:, timestamp: }

        expect(response.status).to eq(400)
      end

      it "returns 400 when timestamp is too old" do
        timestamp = Time.now.to_i - 6.minutes.to_i
        signature =
          OpenSSL::HMAC.hexdigest(
            "sha256",
            hashed_secret,
            "#{client_id}:#{identifier}:#{timestamp}",
          )

        post "/auth/discourse_id/revoke.json", params: { signature:, identifier:, timestamp: }

        expect(response.status).to eq(400)
        expect(response.parsed_body["error"]).to match(/Timestamp is expired/)
      end

      it "returns 400 when user_id is not found" do
        identifier = "non_existent_user_id"
        timestamp = Time.now.to_i
        signature =
          OpenSSL::HMAC.hexdigest(
            "sha256",
            hashed_secret,
            "#{client_id}:#{identifier}:#{timestamp}",
          )

        post "/auth/discourse_id/revoke.json", params: { signature:, identifier:, timestamp: }

        expect(response.status).to eq(400)
        expect(response.parsed_body["error"]).to eq("Invalid request")
      end

      it "returns 400 when client_id or client_secret is blank" do
        SiteSetting.discourse_id_client_id = ""

        timestamp = Time.now.to_i
        signature =
          OpenSSL::HMAC.hexdigest(
            "sha256",
            hashed_secret,
            "#{client_id}:#{identifier}:#{timestamp}",
          )

        post "/auth/discourse_id/revoke.json", params: { signature:, identifier:, timestamp: }

        expect(response.status).to eq(400)
        expect(response.parsed_body["error"]).to eq("Invalid request")

        SiteSetting.discourse_id_client_id = SecureRandom.hex
        SiteSetting.discourse_id_client_secret = ""

        post "/auth/discourse_id/revoke.json", params: { signature:, identifier:, timestamp: }

        expect(response.status).to eq(400)
        expect(response.parsed_body["error"]).to eq("Invalid request")
      end
    end

    context "with rate limiting" do
      before { RateLimiter.enable }

      it "rate limits after 5 requests per minute for the same user_id" do
        identifier = "non_existent_user_id"
        timestamp = Time.now.to_i
        signature = SecureRandom.hex

        5.times do
          post "/auth/discourse_id/revoke.json", params: { signature:, identifier:, timestamp: }
          expect(response.status).to eq(400)
        end

        post "/auth/discourse_id/revoke.json", params: { signature:, identifier:, timestamp: }
        expect(response.status).to eq(429)
      end
    end
  end
end
