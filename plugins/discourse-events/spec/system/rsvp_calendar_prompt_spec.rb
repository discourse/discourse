# frozen_string_literal: true

RSpec.describe "RSVP calendar prompt" do
  fab!(:admin)
  fab!(:user)

  let(:post_event_page) { PageObjects::Pages::DiscourseEvents::PostEvent.new }

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.event_participation_buttons = "going|interested|not going"
    sign_in(user)
  end

  it "offers to add the event to a calendar after Going, including when rejoining",
     time: Time.zone.parse("2026-09-14 12:00:00") do
    post =
      PostCreator.create!(
        admin,
        title: "Conference day breakfast",
        raw:
          "[event start=\"#{2.hours.from_now.iso8601}\" end=\"#{3.hours.from_now.iso8601}\" status=\"public\"]\n[/event]",
      )

    visit(post.topic.url)
    expect(post_event_page).to have_going_button
    expect(post_event_page).to have_no_calendar_prompt

    post_event_page.going
    expect(post_event_page).to have_pressed_status(:going)
    expect(post_event_page).to have_calendar_prompt

    post_event_page.dismiss_calendar_prompt
    expect(post_event_page).to have_no_calendar_prompt
    post_event_page.going
    expect(post_event_page).to have_no_selected_status(:going)

    post_event_page.going
    expect(post_event_page).to have_pressed_status(:going)
    expect(post_event_page).to have_calendar_prompt
  end
end
