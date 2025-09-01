# frozen_string_literal: true

describe "Calendar first day of week", type: :system do
  fab!(:admin)

  let(:upcoming_events) { PageObjects::Pages::DiscourseCalendar::UpcomingEvents.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.calendar_first_day_of_week = "Sunday"
    sign_in(admin)
  end

  it "renders Sunday as the first day in the upcoming events calendar" do
    upcoming_events.visit
    upcoming_events.open_month_view

    # Prefer a structural check via class to avoid locale formatting issues
    expect(upcoming_events.first_column_is_sunday?).to eq(true)

    # As a secondary assertion, the first header label should start with "Sun" (case-insensitive)
    expect(upcoming_events.first_weekday_header_text).to match(/^Sun/i)
  end
end
