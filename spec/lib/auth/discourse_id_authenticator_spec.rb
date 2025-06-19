# frozen_string_literal: true

require "rails_helper"

describe Auth::DiscourseIdAuthenticator do
  let(:authenticator) { described_class.new }
  let(:user) { Fabricate(:user) }

  context "with default settings" do
    before do
      SiteSetting.enable_discourse_id = true
      SiteSetting.discourse_id_client_id = "client_id"
      SiteSetting.discourse_id_client_secret = "client_secret"
    end

    it "has the right name" do
      expect(authenticator.name).to eq("discourse_id")
    end

    it "can connect to existing user" do
      expect(authenticator.can_connect_existing_user?).to eq(true)
    end

    it "can be revoked" do
      expect(authenticator.can_revoke?).to eq(true)
    end

    it "verifies email by default" do
      expect(authenticator.primary_email_verified?({})).to eq(true)
    end

    it "does not always update user email" do
      expect(authenticator.always_update_user_email?).to eq(false)
    end

    describe "#enabled?" do
      it "is enabled with proper settings" do
        expect(authenticator.enabled?).to eq(true)
      end

      it "is disabled without client id" do
        SiteSetting.discourse_id_client_id = ""
        expect(authenticator.enabled?).to eq(false)
      end

      it "is disabled without client secret" do
        SiteSetting.discourse_id_client_secret = ""
        expect(authenticator.enabled?).to eq(false)
      end

      it "is disabled when `discourse_login_client_enabled` is false" do
        SiteSetting.enable_discourse_id = false
        expect(authenticator.enabled?).to eq(false)
      end
    end

    describe "#site" do
      it "returns default URL when setting is blank" do
        SiteSetting.discourse_id_provider_url = ""
        expect(authenticator.site).to eq("https://id.discourse.com")
      end

      it "returns configured URL when setting is present" do
        SiteSetting.discourse_id_provider_url = "https://custom.example.com"
        expect(authenticator.site).to eq("https://custom.example.com")
      end
    end
  end

  describe "DiscourseIdStrategy" do
    let(:strategy) { Auth::DiscourseIdAuthenticator::DiscourseIdStrategy.new({}) }

    it "uses 'discourse_id' name" do
      expect(strategy.options.name).to eq("discourse_id")
    end

    it "uses basic auth as authentication scheme" do
      expect(strategy.options.client_options.auth_scheme).to eq(:basic_auth)
    end

    it "defines callback_url" do
      expect(strategy.callback_url).to eq("http://test.localhost/auth/discourse_id/callback")
    end
  end

  let(:hash) do
    OmniAuth::AuthHash.new(
      provider: "discourse_id",
      info: {
        "nickname" => "test_user",
        "email" => user.email,
        "image" => "http://example.com/avatar.png",
        "uuid" => "12345",
      },
      uid: "99",
    )
  end

  describe "after_authenticate" do
    it "works and syncs username, email, avatar" do
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(user)
      expect(result.failed).to eq(false)

      expect(result.username).to eq("test_user")
      expect(result.email).to eq(user.email)

      associated_record =
        UserAssociatedAccount.find_by(provider_name: "discourse_id", user_id: user.id)

      expect(associated_record[:info]["image"]).to eq("http://example.com/avatar.png")
      expect(associated_record[:info]["uuid"]).to eq("12345")
    end
  end
end
