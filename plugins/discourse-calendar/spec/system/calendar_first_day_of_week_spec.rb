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
    it "renders Monday as the first day" do
      upcoming_events.visit
      upcoming_events.open_month_view

      expect(upcoming_events).to have_first_column_as_monday
    end
  end

  context "when Monday" do
    before { SiteSetting.calendar_first_day_of_week = "Monday" }

    it "renders Monday as the first day" do
      upcoming_events.visit
      upcoming_events.open_month_view

      expect(upcoming_events).to have_first_column_as_monday
    end
  end

  context "when Saturday" do
    before { SiteSetting.calendar_first_day_of_week = "Saturday" }

    it "renders Saturday as the first day" do
      upcoming_events.visit
      upcoming_events.open_month_view

      expect(upcoming_events).to have_first_column_as_saturday
    end
  end

  context "when Sunday" do
    before { SiteSetting.calendar_first_day_of_week = "Sunday" }

    it "renders Sunday as the first day" do
      upcoming_events.visit
      upcoming_events.open_month_view

      expect(upcoming_events).to have_first_column_as_sunday
    end
  end
end
