# frozen_string_literal: true

describe UserSerializer do
  fab!(:user)

  subject(:json) { described_class.new(user, scope: guardian).as_json }

  before do
    SiteSetting.calendar_enabled = true
    user.upsert_custom_fields(DiscourseCalendar::REGION_CUSTOM_FIELD => "uk")
  end

  context "as another user" do
    fab!(:guardian) { Fabricate(:user).guardian }

    it "does not return user region" do
      expect(json[:user][:custom_fields]).to be_blank
    end
  end

  context "as current user" do
    fab!(:guardian) { user.guardian }

    it "returns user region" do
      expect(json[:user][:custom_fields]).to eq(DiscourseCalendar::REGION_CUSTOM_FIELD => "uk")
    end
  end

  context "as staff" do
    fab!(:guardian) { Fabricate(:admin).guardian }

    it "returns user region" do
      expect(json[:user][:custom_fields]).to eq(DiscourseCalendar::REGION_CUSTOM_FIELD => "uk")
    end
  end
end
