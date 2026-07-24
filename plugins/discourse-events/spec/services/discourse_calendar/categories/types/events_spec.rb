# frozen_string_literal: true

RSpec.describe DiscourseCalendar::Categories::Types::Events do
  fab!(:admin)
  fab!(:category)

  describe ".visible?" do
    it "returns true when enable_events_category_type_setup is true" do
      SiteSetting.enable_events_category_type_setup = true
      expect(described_class.visible?).to eq(true)
    end

    it "returns false when enable_events_category_type_setup is false" do
      SiteSetting.enable_events_category_type_setup = false
      expect(described_class.visible?).to eq(false)
    end
  end

  describe ".enable_plugin" do
    it "enables calendar and post-event site settings" do
      SiteSetting.calendar_enabled = false
      SiteSetting.discourse_post_event_enabled = false

      described_class.enable_plugin

      expect(SiteSetting.calendar_enabled).to eq(true)
      expect(SiteSetting.discourse_post_event_enabled).to eq(true)
    end
  end

  describe ".category_matches?" do
    it "returns true when the category id is in events_calendar_categories" do
      SiteSetting.events_calendar_categories = category.id.to_s
      expect(described_class.category_matches?(category)).to eq(true)
    end

    it "returns false when the category id is not in events_calendar_categories" do
      SiteSetting.events_calendar_categories = ""
      expect(described_class.category_matches?(category)).to eq(false)
    end
  end

  describe ".find_matches" do
    fab!(:other_category, :category)

    it "returns categories listed in events_calendar_categories" do
      SiteSetting.events_calendar_categories = "#{category.id}|#{other_category.id}"
      expect(described_class.find_matches).to contain_exactly(category, other_category)
    end

    it "returns no categories when the setting is blank" do
      SiteSetting.events_calendar_categories = ""
      expect(described_class.find_matches).to be_empty
    end
  end

  describe ".configure_category" do
    it "appends the category to events_calendar_categories" do
      SiteSetting.events_calendar_categories = ""
      described_class.configure_category(category, guardian: admin.guardian)
      expect(SiteSetting.events_calendar_categories).to eq(category.id.to_s)
    end

    it "does not duplicate the category id when called twice" do
      SiteSetting.events_calendar_categories = ""
      2.times { described_class.configure_category(category, guardian: admin.guardian) }
      expect(SiteSetting.events_calendar_categories).to eq(category.id.to_s)
    end

    it "writes a calendar_categories entry with the chosen view and weekends" do
      described_class.configure_category(
        category,
        guardian: admin.guardian,
        configuration_values: {
          events_calendar_default_view: "week",
          events_calendar_display_weekends: false,
        },
      )

      expect(SiteSetting.calendar_categories).to include(
        "categoryId=#{category.id};weekends=false;defaultView=week",
      )
    end

    it "uses defaults when configuration values are not provided" do
      described_class.configure_category(category, guardian: admin.guardian)

      expect(SiteSetting.calendar_categories).to include(
        "categoryId=#{category.id};weekends=true;defaultView=month",
      )
    end

    it "replaces an existing calendar_categories entry for the same category" do
      SiteSetting.calendar_categories = "categoryId=#{category.id};weekends=true;defaultView=month"

      described_class.configure_category(
        category,
        guardian: admin.guardian,
        configuration_values: {
          events_calendar_default_view: "year",
          events_calendar_display_weekends: false,
        },
      )

      expect(SiteSetting.calendar_categories).to eq(
        "categoryId=#{category.id};weekends=false;defaultView=year",
      )
    end
  end

  describe ".unconfigure_category" do
    before { described_class.configure_category(category, guardian: admin.guardian) }

    it "removes the category from events_calendar_categories" do
      expect(SiteSetting.events_calendar_categories.split("|")).to include(category.id.to_s)

      described_class.unconfigure_category(category, guardian: admin.guardian)

      expect(SiteSetting.events_calendar_categories.split("|")).not_to include(category.id.to_s)
    end

    it "removes the category's entry from calendar_categories" do
      expect(SiteSetting.calendar_categories).to include("categoryId=#{category.id};")

      described_class.unconfigure_category(category, guardian: admin.guardian)

      expect(SiteSetting.calendar_categories).not_to include("categoryId=#{category.id};")
    end

    it "leaves other categories' calendar_categories entries untouched" do
      other = Fabricate(:category)
      described_class.configure_category(other, guardian: admin.guardian)

      described_class.unconfigure_category(category, guardian: admin.guardian)

      expect(SiteSetting.calendar_categories).to include("categoryId=#{other.id};")
    end
  end

  describe ".read_category_settings" do
    it "returns the stored values when the category has a calendar_categories entry" do
      described_class.configure_category(
        category,
        guardian: admin.guardian,
        configuration_values: {
          events_calendar_default_view: "year",
          events_calendar_display_weekends: false,
        },
      )

      expect(described_class.read_category_settings(category)).to eq(
        events_calendar_default_view: "year",
        events_calendar_display_weekends: false,
      )
    end

    it "returns an empty hash when the category has no entry" do
      expect(described_class.read_category_settings(category)).to eq({})
    end
  end

  describe ".configuration_schema" do
    it "exposes the expected top-level groups" do
      schema = described_class.configuration_schema
      expect(schema.keys).to contain_exactly(
        :general_category_settings,
        :category_settings,
        :site_settings,
      )
    end

    it "presets the prefilled name and emoji" do
      schema = described_class.configuration_schema
      expect(schema[:general_category_settings][:name][:default]).to eq("Events")
      expect(schema[:general_category_settings][:emoji][:default]).to eq("spiral_calendar")
    end

    it "is valid against CONFIGURATION_SCHEMA_DEFINITION" do
      expect { described_class.validate_schema! }.not_to raise_error
    end
  end

  describe "via Categories::Configure" do
    it "wires plugin enable, site settings, and category configuration end-to-end" do
      SiteSetting.enable_events_category_type_setup = true

      result =
        Categories::Configure.call(
          guardian: admin.guardian,
          params: {
            category_id: category.id,
            category_type: "events",
            category_configuration_values: {
              "events_calendar_default_view" => "week",
              "events_calendar_display_weekends" => false,
            },
            site_setting_configuration_values: {
              discourse_post_event_allowed_on_groups: "1|2",
              use_local_event_date: true,
              sort_categories_by_event_start_date_enabled: false,
              sidebar_show_upcoming_events: false,
            },
          },
        )

      expect(result).to be_a_success
      expect(SiteSetting.calendar_enabled).to eq(true)
      expect(SiteSetting.discourse_post_event_enabled).to eq(true)
      expect(SiteSetting.events_calendar_categories).to include(category.id.to_s)
      expect(SiteSetting.discourse_post_event_allowed_on_groups).to eq("1|2")
      expect(SiteSetting.use_local_event_date).to eq(true)
      expect(SiteSetting.sort_categories_by_event_start_date_enabled).to eq(false)
      expect(SiteSetting.sidebar_show_upcoming_events).to eq(false)
      expect(SiteSetting.calendar_categories).to include(
        "categoryId=#{category.id};weekends=false;defaultView=week",
      )
    end
  end
end
