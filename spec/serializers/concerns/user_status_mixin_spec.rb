# frozen_string_literal: true

RSpec.describe UserStatusMixin do
  fab!(:user_status)
  fab!(:user) { Fabricate(:user, user_status:) }

  class DummySerializer < ApplicationSerializer
    include UserStatusMixin
  end

  def serialize_status(scope: Guardian.new(user), include_status: true)
    DummySerializer.new(user, scope:, root: false, include_status:).as_json[:status]
  end

  context "when user status is disabled" do
    before { SiteSetting.enable_user_status = false }

    it "doesn't include status" do
      expect(serialize_status).to be_nil
    end
  end

  context "when user status is enabled" do
    before { SiteSetting.enable_user_status = true }

    it "doesn't include status by default" do
      expect(serialize_status(include_status: false)).to be_nil
    end

    it "includes status when include_status option is passed" do
      expect(serialize_status).to be_present
    end

    it "doesn't include status if user hid profile" do
      user.user_option.hide_profile = true
      expect(serialize_status).to be_nil
    end

    it "respects guardian's can_see_user_status?" do
      user.update!(silenced_till: 1.year.from_now)

      # own status is visible
      expect(serialize_status).to be_present

      # other user's status is not visible
      expect(serialize_status(scope: Guardian.new(Fabricate(:user)))).to be_nil
    end
  end
end
