# frozen_string_literal: true

describe "DiscourseRewind | dismiss", type: :system do
  fab!(:user) { Fabricate(:user, created_at: DateTime.parse("2020-01-01")) }
  let(:rewind_page) { PageObjects::Pages::Rewind.new }

  before do
    SiteSetting.discourse_rewind_enabled = true
    sign_in(user)
    freeze_time DateTime.parse("2022-12-05")
  end

  it "persists dismiss across page refreshes and saves to database" do
    rewind_page.visit_my_activity
    expect(rewind_page).to have_rewind_notification_active

    rewind_page.open_user_menu
    expect(rewind_page).to have_callout
    rewind_page.click_callout

    expect(rewind_page).to have_no_rewind_notification_active
    expect(user.user_option.reload.discourse_rewind_dismissed_at).to be_present

    visit("/")
    rewind_page.visit_my_activity
    expect(rewind_page).to have_no_rewind_notification_active
  end

  it "hides notification and callout when already dismissed" do
    user.user_option.update!(discourse_rewind_dismissed_at: Time.current)

    rewind_page.visit_my_activity
    expect(rewind_page).to have_no_rewind_notification_active

    rewind_page.open_user_menu
    expect(rewind_page).to have_no_callout
  end

  it "shows notification for new year even if previous year was dismissed" do
    user.user_option.update!(discourse_rewind_dismissed_at: DateTime.parse("2021-12-15"))

    rewind_page.visit_my_activity
    expect(rewind_page).to have_rewind_notification_active
  end
end
