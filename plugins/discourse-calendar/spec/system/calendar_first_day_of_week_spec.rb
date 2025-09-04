# frozen_string_literal: true

describe "Calendar first day of week", type: :system do
  fab!(:admin)

  let(:upcoming_events) { PageObjects::Pages::DiscourseCalendar::UpcomingEvents.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    sign_in(admin)
  end

  context "when default" do
    it "renders monday as the first day" do
      upcoming_events.visit
      upcoming_events.open_month_view

      expect(upcoming_events).to have_first_column_as_monday
    end
  end

  context "when monday" do
    before { SiteSetting.calendar_first_day_of_week = "monday" }

    it "renders monday as the first day" do
      upcoming_events.visit
      upcoming_events.open_month_view

      expect(upcoming_events).to have_first_column_as_monday
    end
  end

  context "when saturday" do
    before { SiteSetting.calendar_first_day_of_week = "saturday" }

    it "renders saturday as the first day" do
      upcoming_events.visit
      upcoming_events.open_month_view

      expect(upcoming_events).to have_first_column_as_saturday
    end
  end

  context "when sunday" do
    before { SiteSetting.calendar_first_day_of_week = "sunday" }

    it "renders sunday as the first day" do
      upcoming_events.visit
      upcoming_events.open_month_view

      expect(upcoming_events).to have_first_column_as_sunday
    end
  end
end
