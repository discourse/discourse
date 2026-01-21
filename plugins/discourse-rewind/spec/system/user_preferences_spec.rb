# frozen_string_literal: true

describe "DiscourseRewind | user preferences", type: :system do
  fab!(:current_user) { Fabricate(:user, created_at: DateTime.parse("2020-01-01")) }
  let(:rewind_page) { PageObjects::Pages::Rewind.new }

  before do
    SiteSetting.discourse_rewind_enabled = true
    sign_in(current_user)
  end

  context "when in december" do
    before { freeze_time DateTime.parse("2022-12-05") }

    context "when discourse_rewind_enabled is true" do
      it "shows the rewind tab" do
        rewind_page.visit_my_activity
        expect(rewind_page).to have_rewind_tab
      end

      it "shows the rewind profile link" do
        rewind_page.visit_my_activity
        rewind_page.open_user_menu
        rewind_page.click_profile_tab
        expect(rewind_page).to have_rewind_profile_link
      end

      it "shows the rewind preferences nav link" do
        rewind_page.visit_my_preferences
        expect(rewind_page).to have_rewind_preferences_nav
      end
    end

    context "when discourse_rewind_enabled is false" do
      before { current_user.user_option.update!(discourse_rewind_enabled: false) }

      it "does not show the rewind tab" do
        rewind_page.visit_my_activity
        expect(rewind_page).to have_no_rewind_tab
      end

      it "does not show the rewind profile link" do
        rewind_page.visit_my_activity
        rewind_page.open_user_menu
        rewind_page.click_profile_tab
        expect(rewind_page).to have_no_rewind_profile_link
      end
    end

    context "when user account is less than one month old" do
      before { current_user.update!(created_at: DateTime.parse("2022-11-20")) }

      it "does not show the rewind preferences nav link" do
        rewind_page.visit_my_preferences
        expect(rewind_page).to have_no_rewind_preferences_nav
      end
    end
  end
end
