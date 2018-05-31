require 'rails_helper'

RSpec.describe CurrentUserSerializer do
  context "when SSO is not enabled" do
    let(:user) { Fabricate(:user) }
    let :serializer do
      CurrentUserSerializer.new(user, scope: Guardian.new, root: false)
    end

    it "should not include the external_id field" do
      payload = serializer.as_json
      expect(payload).not_to have_key(:external_id)
    end
  end

  context "when SSO is enabled" do
    let :user do
      user = Fabricate(:user)
      SingleSignOnRecord.create!(user_id: user.id, external_id: '12345', last_payload: '')
      user
    end

    let :serializer do
      CurrentUserSerializer.new(user, scope: Guardian.new, root: false)
    end

    it "should include the external_id" do
      SiteSetting.sso_url = "http://example.com/discourse_sso"
      SiteSetting.sso_secret = "12345678910"
      SiteSetting.enable_sso = true
      payload = serializer.as_json
      expect(payload[:external_id]).to eq("12345")
    end
  end
end
