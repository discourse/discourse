# frozen_string_literal: true

RSpec.describe DiscourseEvents::Events::SchemaMarkup do
  before { SiteSetting.enable_event_schema_for_topics = true }

  it "builds Schema.org Event markup for a topic" do
    event =
      event_double(
        description: "Meet **the community**",
        starts_at: Time.iso8601("2026-10-22T13:00:00Z"),
        ends_at: Time.iso8601("2026-10-22T14:00:00Z"),
        timezone: "America/New_York",
      )
    allow(DiscourseEvents::Events::Parser).to receive(:cook_inline).and_return(
      "Meet <strong>the community</strong>",
    )

    schema = schema_from(described_class.build(topic_view(event)))

    expect(schema).to include(
      "@context" => "https://schema.org",
      "@type" => "Event",
      "name" => "Community hangout",
      "description" => "Meet the community",
      "startDate" => "2026-10-22T09:00:00.000-04:00",
      "endDate" => "2026-10-22T10:00:00.000-04:00",
      "eventStatus" => "https://schema.org/EventScheduled",
      "url" => "https://test.localhost/t/community-hangout/123",
    )
  end

  it "keeps all-day event dates independent of timezones" do
    event =
      event_double(
        all_day: true,
        starts_at: Time.iso8601("2026-10-22T10:00:00Z"),
        ends_at: Time.iso8601("2026-10-23T10:00:00Z"),
        timezone: "Pacific/Honolulu",
      )

    expect(schema_from(described_class.build(topic_view(event)))).to include(
      "startDate" => "2026-10-22",
      "endDate" => "2026-10-23",
    )
  end

  it "returns no markup when the setting is disabled" do
    SiteSetting.enable_event_schema_for_topics = false

    expect(described_class.build(topic_view(event_double))).to be_nil
  end

  it "returns no markup for an ordinary topic" do
    topic = instance_double(Topic, first_post: instance_double(Post, event: nil))

    expect(described_class.build(Struct.new(:topic).new(topic))).to be_nil
  end

  def event_double(overrides = {})
    defaults = {
      all_day: false,
      deleted_at: nil,
      description: nil,
      starts_at: nil,
      ends_at: nil,
      name: nil,
      post: nil,
      timezone: "UTC",
    }
    instance_double(DiscourseEvents::Events::Event, **defaults.merge(overrides))
  end

  def topic_view(event)
    topic =
      instance_double(
        Topic,
        first_post: instance_double(Post, event:),
        title: "Community hangout",
        url: "https://test.localhost/t/community-hangout/123",
      )
    Struct.new(:topic).new(topic)
  end

  def schema_from(html)
    JSON.parse(Nokogiri::HTML5.fragment(html).at_css('script[type="application/ld+json"]').text)
  end
end
