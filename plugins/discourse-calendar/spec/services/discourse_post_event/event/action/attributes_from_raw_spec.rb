# frozen_string_literal: true

RSpec.describe DiscoursePostEvent::Event::Action::AttributesFromRaw do
  subject(:attributes) { described_class.call(raw_event:, current_status:) }

  let(:current_status) { DiscoursePostEvent::Event.statuses[:public] }
  let(:raw_event) { { name: "My event", start: "2030-04-24 14:15", timezone: "Europe/Paris" } }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  it "passes through the simple string attributes" do
    raw_event.merge!(
      name: "Party",
      url: "https://example.com",
      description: "A nice party",
      location: "Somewhere",
      recurrence: "every_week",
      reminders: "1.hours",
    )

    expect(attributes).to include(
      name: "Party",
      url: "https://example.com",
      description: "A nice party",
      location: "Somewhere",
      recurrence: "every_week",
      reminders: "1.hours",
    )
  end

  context "with timezone parsing" do
    it "parses start, end and recurrence-until in the event timezone" do
      raw_event.merge!(
        start: "2030-04-24 14:15",
        end: "2030-04-24 18:15",
        "recurrence-until": "2030-05-24 14:15",
        timezone: "Europe/Paris",
      )

      paris = ActiveSupport::TimeZone["Europe/Paris"]
      expect(attributes[:original_starts_at]).to eq(paris.parse("2030-04-24 14:15"))
      expect(attributes[:original_ends_at]).to eq(paris.parse("2030-04-24 18:15"))
      expect(attributes[:recurrence_until]).to eq(paris.parse("2030-05-24 14:15"))
      expect(attributes[:timezone]).to eq("Europe/Paris")
    end

    it "falls back to the default timezone when none is provided" do
      raw_event.merge!(start: "2030-04-24 14:15", timezone: nil)

      utc = ActiveSupport::TimeZone[DiscoursePostEvent::Event::DEFAULT_TIMEZONE]
      expect(attributes[:original_starts_at]).to eq(utc.parse("2030-04-24 14:15"))
    end

    it "leaves end and recurrence-until nil when absent" do
      expect(attributes[:original_ends_at]).to be_nil
      expect(attributes[:recurrence_until]).to be_nil
    end
  end

  context "with an all-day event" do
    before { raw_event.merge!("all-day": "true", start: "2030-04-24", timezone: "Europe/Paris") }

    it "parses the start as a UTC date ignoring the timezone" do
      expect(attributes[:all_day]).to eq(true)
      expect(attributes[:original_starts_at]).to eq(Time.utc(2030, 4, 24))
    end

    it "parses the end as the UTC end of day when provided" do
      raw_event[:end] = "2030-04-26"

      expect(attributes[:original_ends_at]).to eq(Time.utc(2030, 4, 26).end_of_day)
    end

    it "leaves the end nil when absent" do
      expect(attributes[:original_ends_at]).to be_nil
    end
  end

  context "with boolean coercion" do
    it "coerces show-local-time, chat-enabled and closed" do
      raw_event.merge!("show-local-time": "true", "chat-enabled": "TRUE", closed: true)

      expect(attributes).to include(show_local_time: true, chat_enabled: true, closed: true)
    end

    it "defaults the booleans to false when absent" do
      expect(attributes).to include(show_local_time: false, chat_enabled: false, closed: false)
    end
  end

  context "with status resolution" do
    it "resolves a known raw status to its enum value" do
      raw_event[:status] = "private"

      expect(attributes[:status]).to eq(DiscoursePostEvent::Event.statuses[:private])
    end

    it "falls back to the current status when the raw status is missing" do
      expect(attributes[:status]).to eq(current_status)
    end

    it "falls back to the current status when the raw status is unknown" do
      raw_event[:status] = "bogus"

      expect(attributes[:status]).to eq(current_status)
    end
  end

  it "coerces max-attendees to an integer" do
    raw_event[:"max-attendees"] = "12"

    expect(attributes[:max_attendees]).to eq(12)
  end

  it "splits allowed-groups into raw_invitees" do
    raw_event[:"allowed-groups"] = "trust_level_0,staff"

    expect(attributes[:raw_invitees]).to eq(%w[trust_level_0 staff])
  end

  it "leaves raw_invitees nil when allowed-groups is absent" do
    expect(attributes[:raw_invitees]).to be_nil
  end

  context "with custom fields" do
    it "only keeps fields listed in the site setting that have a value" do
      SiteSetting.discourse_post_event_allowed_custom_fields = "field_a|field_b"
      raw_event.merge!(field_a: "value", field_b: "", field_c: "ignored")

      expect(attributes[:custom_fields]).to eq("field_a" => "value")
    end

    it "is empty when the site setting is blank" do
      SiteSetting.discourse_post_event_allowed_custom_fields = ""
      raw_event[:field_a] = "value"

      expect(attributes[:custom_fields]).to eq({})
    end
  end
end
