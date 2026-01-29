# frozen_string_literal: true

RSpec.describe Categories::Types::Events do
  describe ".available?" do
    context "when discourse-calendar is not loaded" do
      before { allow(described_class).to receive(:available?).and_call_original }

      it "returns false when DiscourseCalendar is not defined" do
        hide_const("DiscourseCalendar") if defined?(DiscourseCalendar)
        expect(described_class.available?).to be_falsey
      end
    end

    context "when discourse-calendar is loaded", if: defined?(DiscourseCalendar) do
      it "returns true" do
        expect(described_class.available?).to be true
      end
    end
  end

  describe ".type_id" do
    it "returns :events" do
      expect(described_class.type_id).to eq(:events)
    end
  end

  describe ".icon" do
    it "returns calendar-days" do
      expect(described_class.icon).to eq("calendar-days")
    end
  end

  describe ".enable_plugin", if: defined?(DiscourseCalendar) do
    it "enables the calendar_enabled setting" do
      SiteSetting.calendar_enabled = false
      SiteSetting.discourse_post_event_enabled = false

      described_class.enable_plugin

      expect(SiteSetting.calendar_enabled).to be true
      expect(SiteSetting.discourse_post_event_enabled).to be true
    end

    it "sets default allowed groups if empty" do
      SiteSetting.discourse_post_event_allowed_on_groups = ""

      described_class.enable_plugin

      expect(SiteSetting.discourse_post_event_allowed_on_groups).to eq(
        Group::AUTO_GROUPS[:staff].to_s,
      )
    end

    it "does not override existing allowed groups" do
      SiteSetting.discourse_post_event_allowed_on_groups = "1|2|3"

      described_class.enable_plugin

      expect(SiteSetting.discourse_post_event_allowed_on_groups).to eq("1|2|3")
    end
  end

  describe ".configure_site_settings", if: defined?(DiscourseCalendar) do
    fab!(:category)

    it "adds category to events_calendar_categories" do
      SiteSetting.events_calendar_categories = ""

      described_class.configure_site_settings(category)

      expect(SiteSetting.events_calendar_categories).to eq(category.id.to_s)
    end

    it "appends to existing categories list" do
      SiteSetting.events_calendar_categories = "999"

      described_class.configure_site_settings(category)

      expect(SiteSetting.events_calendar_categories).to eq("999|#{category.id}")
    end

    it "does not duplicate category in list" do
      SiteSetting.events_calendar_categories = category.id.to_s

      described_class.configure_site_settings(category)

      expect(SiteSetting.events_calendar_categories).to eq(category.id.to_s)
    end
  end

  describe ".configure_category" do
    fab!(:category)

    it "sets the sort_topics_by_event_start_date custom field" do
      described_class.configure_category(category)

      category.reload
      expect(category.custom_fields["sort_topics_by_event_start_date"]).to eq("t")
    end
  end
end
