# frozen_string_literal: true

describe "DiscourseRewind | user preferences", type: :system do
  fab!(:current_user, :user)
  let(:rewind_page) { PageObjects::Pages::Rewind.new }

  before do
    SiteSetting.discourse_rewind_enabled = true
    sign_in(current_user)
  end

  context "when in december" do
    before { freeze_time DateTime.parse("2022-12-05") }

    context "when discourse_rewind_disabled is false" do
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
    end

    context "when discourse_rewind_disabled is true" do
      before { current_user.user_option.update!(discourse_rewind_disabled: true) }

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
  end
end
