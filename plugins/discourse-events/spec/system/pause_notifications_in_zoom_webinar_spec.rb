# frozen_string_literal: true

describe "Pause notifications in a Zoom webinar" do
  fab!(:current_user) { Fabricate(:user, trust_level: 1) }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:paused_indicator) { ".header-dropdown-toggle .do-not-disturb-background" }

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.livestream_zoom_enabled = true
    SiteSetting.livestream_zoom_sdk_key = "blah"
    SiteSetting.livestream_zoom_sdk_secret = "blah"

    sign_in(current_user)
  end

  def visit_meeting
    topic =
      create_post_with_event(
        Fabricate(:admin),
        'status="public" livestream="true" location="https://zoom.us/j/1234567890"',
      ).topic

    visit("/t/#{topic.slug}/#{topic.id}/zoom")
  end

  it "pauses notifications on joining and resumes them when the meeting is left" do
    visit_meeting

    expect(toasts).to have_default(
      I18n.t("js.discourse_events.livestream.zoom.pause_notifications.paused"),
    )
    expect(page).to have_css(paused_indicator)

    find("#site-logo").click

    expect(page).to have_current_path("/")
    expect(page).to have_no_css(paused_indicator)
    expect(toasts).to have_no_message
  end

  it "pauses notifications again when the meeting is reloaded" do
    visit_meeting

    expect(page).to have_css(paused_indicator)

    page.refresh

    expect(toasts).to have_default(
      I18n.t("js.discourse_events.livestream.zoom.pause_notifications.paused"),
    )
    expect(page).to have_css(paused_indicator)
    expect(current_user.reload.do_not_disturb?).to eq(true)
  end

  it "resumes notifications from the toast" do
    visit_meeting

    expect(page).to have_css(paused_indicator)

    click_button(I18n.t("js.discourse_events.livestream.zoom.pause_notifications.resume"))

    expect(page).to have_no_css(paused_indicator)
    expect(toasts).to have_no_message
  end

  it "leaves a user who has already paused notifications alone" do
    current_user.do_not_disturb_timings.create!(starts_at: Time.zone.now, ends_at: 1.day.from_now)

    visit_meeting

    expect(page).to have_css(paused_indicator)
    expect(toasts).to have_no_message

    find("#site-logo").click

    expect(page).to have_current_path("/")
    expect(page).to have_css(paused_indicator)
  end
end
