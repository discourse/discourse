# frozen_string_literal: true

RSpec.describe GroupUserWithCustomFieldsSerializer do
  describe "#status" do
    fab!(:user_status)
    fab!(:user) { Fabricate(:user, user_status: user_status) }

    it "adds user status when enabled in site settings" do
      SiteSetting.enable_user_status = true

      serializer = described_class.new(user, scope: Guardian.new(user), root: false)
      json = serializer.as_json

      expect(json[:status]).to be_present
    end
  end
end
