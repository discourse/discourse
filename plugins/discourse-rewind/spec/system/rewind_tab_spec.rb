# frozen_string_literal: true

describe "DiscourseRewind | rewind tab", type: :system do
  fab!(:current_user, :user)

  before do
    SiteSetting.discourse_rewind_enabled = true
    sign_in(current_user)
  end

  context "when in january" do
    before { freeze_time DateTime.parse("2022-01-10") }

    it "shows the tab" do
      visit("/my/activity")

      expect(page).to have_selector(".user-nav__activity-rewind")
    end
  end

  context "when in december" do
    before { freeze_time DateTime.parse("2022-12-05") }

    it "shows the tab" do
      visit("/my/activity")

      expect(page).to have_selector(".user-nav__activity-rewind")
    end
  end

  context "when in november" do
    before { freeze_time DateTime.parse("2022-11-24") }

    it "doesn't show the tab" do
      visit("/my/activity")

      expect(page).to have_no_selector(".user-nav__activity-rewind")
    end
  end
end
