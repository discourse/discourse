# frozen_string_literal: true

RSpec.describe UserStatusMixin do
  fab!(:user_status)
  fab!(:user) { Fabricate(:user, user_status: user_status) }

  class DummySerializer < ApplicationSerializer
    include UserStatusMixin
  end

  context "when user status is disabled" do
    before { SiteSetting.enable_user_status = false }

    it "doesn't include status" do
      serializer = DummySerializer.new(user, root: false, include_status: true)
      json = serializer.as_json
      expect(json[:status]).to be_nil
    end
  end

  context "when user status is enabled" do
    before { SiteSetting.enable_user_status = true }

    it "doesn't include status by default" do
      serializer = DummySerializer.new(user, root: false)
      json = serializer.as_json
      expect(json[:status]).to be_nil
    end

    it "includes status when include_status option is passed" do
      serializer = DummySerializer.new(user, root: false, include_status: true)
      json = serializer.as_json
      expect(json[:status]).to be_present
    end

    it "doesn't include status if user hid profile and presence" do
      user.user_option.hide_profile = true
      serializer = DummySerializer.new(user, root: false, include_status: true)
      json = serializer.as_json
      expect(json[:status]).to be_nil
    end
  end
end
