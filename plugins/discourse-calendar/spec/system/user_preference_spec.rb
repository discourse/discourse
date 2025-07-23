# frozen_string_literal: true

RSpec.describe "User Preferences", system: true do
  fab!(:user)

  before { SiteSetting.calendar_enabled = true }

  context "when in the user preferences page" do
    before do
      sign_in(user)
      visit("/u/#{user.username_lower}/preferences/profile")
    end

    it "should show `region` input with `user-custom-preferences-outlet`" do
      expect(page).to have_selector(".user-custom-preferences-outlet > .control-group.region")
    end
  end
end
