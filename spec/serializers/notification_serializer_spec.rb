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

    it "should include the external_id" do
      SiteSetting.discourse_connect_url = "http://example.com/discourse_sso"
      SiteSetting.discourse_connect_secret = "12345678910"
      SiteSetting.enable_discourse_connect = true
      expect(json[:notification][:external_id]).to eq("12345")
    end
  end
end
