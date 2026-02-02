# frozen_string_literal: true

describe "DiscourseRewind | rewind tab", type: :system do
  fab!(:current_user) { Fabricate(:user, created_at: DateTime.parse("2020-01-01")) }
  let(:rewind_page) { PageObjects::Pages::Rewind.new }

  before do
    SiteSetting.discourse_rewind_enabled = true
    sign_in(current_user)
  end

  context "when in january" do
    before { freeze_time DateTime.parse("2022-01-10") }

    it "shows the tab" do
      rewind_page.visit_my_activity
      expect(rewind_page).to have_rewind_tab
    end
  end

  context "when in december" do
    before { freeze_time DateTime.parse("2022-12-05") }

    it "shows the tab" do
      rewind_page.visit_my_activity
      expect(rewind_page).to have_rewind_tab
    end
  end

  context "when in november" do
    before { freeze_time DateTime.parse("2022-11-24") }

    it "doesn't show the tab" do
      rewind_page.visit_my_activity
      expect(rewind_page).to have_no_rewind_tab
    end
  end

  context "when user account is less than one month old" do
    before do
      freeze_time DateTime.parse("2022-12-05")
      current_user.update!(created_at: DateTime.parse("2022-11-20"))
    end

    it "doesn't show the tab" do
      rewind_page.visit_my_activity
      expect(rewind_page).to have_no_rewind_tab
    end
  end
end
