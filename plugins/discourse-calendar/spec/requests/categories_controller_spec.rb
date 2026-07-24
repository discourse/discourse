# frozen_string_literal: true

describe CategoriesController do
  fab!(:admin)
  fab!(:category)

  before do
    SiteSetting.enable_events_category_type_setup = true
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    DiscourseCalendar::Categories::Types::Events.configure_category(
      category,
      guardian: admin.guardian,
    )
    sign_in(admin)
  end

  describe "#update" do
    it "persists category_type_settings into calendar_categories" do
      put "/categories/#{category.id}.json",
          params: {
            category_type_settings: {
              events_calendar_default_view: "week",
              events_calendar_display_weekends: false,
            },
          }

      expect(response.status).to eq(200)
      expect(SiteSetting.calendar_categories).to include(
        "categoryId=#{category.id};weekends=false;defaultView=week",
      )
    end

    it "leaves calendar_categories untouched when category_type_settings is absent" do
      original = SiteSetting.calendar_categories

      put "/categories/#{category.id}.json", params: { name: "Renamed Events" }

      expect(response.status).to eq(200)
      expect(SiteSetting.calendar_categories).to eq(original)
    end

    it "preserves unspecified category_type_settings when only one key is sent" do
      DiscourseCalendar::Categories::Types::Events.configure_category(
        category,
        guardian: admin.guardian,
        configuration_values: {
          events_calendar_default_view: "year",
          events_calendar_display_weekends: false,
        },
      )

      put "/categories/#{category.id}.json",
          params: {
            category_type_settings: {
              events_calendar_default_view: "week",
            },
          }

      expect(response.status).to eq(200)
      expect(SiteSetting.calendar_categories).to include(
        "categoryId=#{category.id};weekends=false;defaultView=week",
      )
    end

    it "persists site setting edits via category_type_site_settings" do
      put "/categories/#{category.id}.json",
          params: {
            category_type_site_settings: {
              sidebar_show_upcoming_events: false,
            },
          }

      expect(response.status).to eq(200)
      expect(SiteSetting.sidebar_show_upcoming_events).to eq(false)
    end
  end
end
