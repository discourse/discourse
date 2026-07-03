# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::ApprovalTokenStore do
  subject(:store) { described_class.new(session: session, user: user) }

  fab!(:user)
  fab!(:other_user, :user)

  let(:session) { {} }
  let(:device_code) { SecureRandom.hex(32) }

  describe "#create!" do
    it "stores an approval token bound to the device code and user" do
      token = store.create!(device_code)

      expect(token).to be_present
      expect(store.device_code_for(token)).to eq(device_code)
      expect(session[described_class::SESSION_KEY][token]).to include(
        "device_code" => device_code,
        "user_id" => user.id,
      )
    end

    it "removes expired tokens before storing a new one" do
      session[described_class::SESSION_KEY] = {
        "expired" => {
          "device_code" => SecureRandom.hex(32),
          "user_id" => user.id,
          "created_at" => (UserApiKey::DeviceAuth::DEVICE_AUTH_TTL + 1.minute).ago.iso8601,
        },
      }

      store.create!(device_code)

      expect(session[described_class::SESSION_KEY]).not_to have_key("expired")
    end

    it "keeps at most the latest tokens" do
      tokens = Array.new(described_class::MAX_TOKENS + 1) { store.create!(SecureRandom.hex(32)) }

      expect(session[described_class::SESSION_KEY].length).to eq(described_class::MAX_TOKENS)
      expect(session[described_class::SESSION_KEY]).not_to have_key(tokens.first)
      expect(session[described_class::SESSION_KEY]).to have_key(tokens.last)
    end
  end

  describe "#device_code_for" do
    it "returns nil when the token is unknown" do
      expect(store.device_code_for("missing")).to be_nil
    end

    it "returns nil when the token belongs to another user" do
      token = store.create!(device_code)

      expect(
        described_class.new(session: session, user: other_user).device_code_for(token),
      ).to be_nil
    end

    it "returns nil when the token is expired" do
      token = store.create!(device_code)
      session[described_class::SESSION_KEY][token]["created_at"] = (
        UserApiKey::DeviceAuth::DEVICE_AUTH_TTL + 1.minute
      ).ago.iso8601

      expect(store.device_code_for(token)).to be_nil
    end

    it "returns nil when the timestamp is malformed" do
      token = store.create!(device_code)
      session[described_class::SESSION_KEY][token]["created_at"] = "not-a-date"

      expect(store.device_code_for(token)).to be_nil
    end

    it "returns nil when the device code is malformed" do
      token = store.create!(device_code)
      session[described_class::SESSION_KEY][token]["device_code"] = "invalid"

      expect(store.device_code_for(token)).to be_nil
    end
  end

  describe "#delete!" do
    it "removes the token" do
      token = store.create!(device_code)

      store.delete!(token)

      expect(store.device_code_for(token)).to be_nil
      expect(session[described_class::SESSION_KEY]).not_to have_key(token)
    end
  end
end
