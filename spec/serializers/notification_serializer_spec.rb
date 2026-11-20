# frozen_string_literal: true

RSpec.describe NotificationSerializer do
  describe "#as_json" do
    fab!(:user)
    let(:notification) { Fabricate(:notification, user: user) }
    let(:serializer) { NotificationSerializer.new(notification) }
    let(:json) { serializer.as_json }

    it "returns the user_id" do
      expect(json[:notification][:user_id]).to eq(user.id)
    end

    it "does not include external_id when sso is disabled" do
      expect(json[:notification].key?(:external_id)).to eq(false)
    end

    it "removes name fields from notification data when names are disabled" do
      SiteSetting.enable_names = false
      notification.update!(
        data: {
          display_name: "Display Name",
          name: "Name",
          name2: "Second Name",
          original_name: "Original Name",
          safe_key: "safe value",
        }.to_json,
      )

      expect(json[:notification][:data]).to eq("safe_key" => "safe value")
    end
  end

  describe "#sso_enabled" do
    let :user do
      user = Fabricate(:user)
      SingleSignOnRecord.create!(user_id: user.id, external_id: "12345", last_payload: "")
      user
    end
    let(:notification) { Fabricate(:notification, user: user) }
    let(:serializer) { NotificationSerializer.new(notification) }
    let(:json) { serializer.as_json }

    it "includes the external ID" do
      SiteSetting.discourse_connect_url = "http://example.com/discourse_sso"
      SiteSetting.discourse_connect_secret = "12345678910"
      SiteSetting.enable_discourse_connect = true
      expect(json[:notification][:external_id]).to eq("12345")
    end
  end

  describe "localizations" do
    fab!(:topic) { Fabricate(:topic, locale: "ja") }
    fab!(:user)

    before { I18n.locale = "ja" }

    it "returns the locale if there is a topic" do
      SiteSetting.content_localization_enabled = true

      notification = Fabricate(:notification, user:, topic:)
      serializer = NotificationSerializer.new(notification)
      json = serializer.as_json
      expect(json[:notification][:locale]).to eq("ja")
    end

    it "skips locale if there is no topic" do
      SiteSetting.content_localization_enabled = true

      notification = Fabricate(:notification, user:)
      serializer = NotificationSerializer.new(notification)
      json = serializer.as_json
      expect(json[:notification][:locale]).to eq(nil)
    end
  end
end
