# frozen_string_literal: true

describe "DiscourseRewind | rewind avatar decoration and callout", type: :system do
  fab!(:current_user, :user)

  before do
    SiteSetting.discourse_rewind_enabled = true
    sign_in(current_user)
  end

  context "when in december" do
    before { freeze_time DateTime.parse("2022-12-05") }

    it "shows avatar decoration and callout" do
      visit("/")

      expect(page).to have_css("body.rewind-notification-active")
      find("#toggle-current-user").click
      expect(page).to have_css(".rewind-callout__container")
    end

    context "when the user dismisses rewind by clicking the callout" do
      it "no longer shows the callout" do
        visit("/")

        expect(page).to have_css("body.rewind-notification-active")
        find("#toggle-current-user").click
        find(".rewind-callout__container .rewind-callout").click
        expect(page).to have_css(".rewind .rewind__header")
        expect(page).to have_current_path("/u/#{current_user.username}/activity/rewind")

        visit("/")
        expect(page).to have_no_css("body.rewind-notification-active")
      end
    end
  end

  context "when in november" do
    before { freeze_time DateTime.parse("2022-11-24") }

    it "doesn't show the avatar decoration and callout" do
      visit("/")

      expect(page).to have_no_css("body.rewind-notification-active")
    end
  end
end
