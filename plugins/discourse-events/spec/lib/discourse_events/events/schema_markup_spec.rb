# frozen_string_literal: true

RSpec.describe DiscourseEvents::Events::SchemaMarkup do
  before do
    SiteSetting.enable_event_schema_for_topics = true
    SiteSetting.discourse_post_event_enabled = true
  end

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
    %w[America/New_York Pacific/Kiritimati].each do |timezone|
      event =
        event_double(
          all_day: true,
          starts_at: Time.utc(2026, 10, 22),
          ends_at: Time.utc(2026, 10, 23, 23, 59, 59),
          timezone:,
        )

      expect(schema_from(described_class.build(topic_view(event)))).to include(
        "startDate" => "2026-10-22",
        "endDate" => "2026-10-23",
      )
    end
  end

  describe "location" do
    it "describes an online event" do
      expect(schema_from(described_class.build(topic_view(event_double)))).to include(
        "eventAttendanceMode" => "https://schema.org/OnlineEventAttendanceMode",
        "location" => {
          "@type" => "VirtualLocation",
          "url" => "https://meet.example.com/hangout",
        },
      )
    end

    it "describes an in-person event" do
      event = event_double(location: "[Town hall](https://example.com/hall)", url: nil)

      expect(schema_from(described_class.build(topic_view(event)))).to include(
        "eventAttendanceMode" => "https://schema.org/OfflineEventAttendanceMode",
        "location" => {
          "@type" => "Place",
          "name" => "Town hall",
          "address" => "Town hall",
        },
      )
    end

    it "describes an event that is both in person and online" do
      schema = schema_from(described_class.build(topic_view(event_double(location: "Town hall"))))

      expect(schema["eventAttendanceMode"]).to eq("https://schema.org/MixedEventAttendanceMode")
      expect(schema["location"].map { |location| location["@type"] }).to eq(
        %w[Place VirtualLocation],
      )
    end

    it "treats a location that is only a link as online" do
      event = event_double(location: "https://stream.example.com/live", url: nil)

      expect(schema_from(described_class.build(topic_view(event)))).to include(
        "eventAttendanceMode" => "https://schema.org/OnlineEventAttendanceMode",
        "location" => {
          "@type" => "VirtualLocation",
          "url" => "https://stream.example.com/live",
        },
      )
    end

    it "ignores a URL that isn't a web link" do
      event = event_double(location: "Town hall", url: "javascript:alert(1)")

      expect(schema_from(described_class.build(topic_view(event)))["location"]).to include(
        "@type" => "Place",
      )
    end

    it "uses the topic URL when the event has neither a location nor a URL" do
      expect(schema_from(described_class.build(topic_view(event_double(url: nil))))).to include(
        "eventAttendanceMode" => "https://schema.org/OnlineEventAttendanceMode",
        "location" => {
          "@type" => "VirtualLocation",
          "url" => "https://test.localhost/t/community-hangout/123",
        },
      )
    end
  end

  describe "image" do
    let(:upload) do
      instance_double(
        Upload,
        id: 42,
        url: "/uploads/default/original/1X/event.jpeg",
        width: 800,
        height: 1200,
        secure?: false,
      )
    end

    it "uses the topic's share-sized image when it was synced from the event" do
      share_image_url = "#{Discourse.base_url}/uploads/default/optimized/1X/event_2_683x1024.jpeg"
      view =
        topic_view(
          event_double(image_upload: upload),
          image_upload_id: 42,
          image_url: share_image_url,
        )

      expect(schema_from(described_class.build(view))["image"]).to eq(
        "@type" => "ImageObject",
        "url" => share_image_url,
        "width" => 800,
        "height" => 1200,
      )
    end

    it "uses the event's own upload when the topic image differs" do
      view = topic_view(event_double(image_upload: upload), image_upload_id: 7)

      expect(schema_from(described_class.build(view))["image"]).to include(
        "url" => "#{Discourse.base_url}/uploads/default/original/1X/event.jpeg",
      )
    end

    it "is omitted for secure uploads" do
      allow(upload).to receive(:secure?).and_return(true)

      expect(
        schema_from(described_class.build(topic_view(event_double(image_upload: upload)))),
      ).not_to have_key("image")
    end

    it "is omitted when the event has no image" do
      expect(schema_from(described_class.build(topic_view(event_double)))).not_to have_key("image")
    end
  end

  it "uses the first post the topic view already loaded" do
    view = topic_view(event_double)
    allow(view.topic).to receive(:first_post)
    view.posts = [instance_double(Post, post_number: 1, event: event_double(name: "Loaded"))]

    expect(schema_from(described_class.build(view))["name"]).to eq("Loaded")
    expect(view.topic).not_to have_received(:first_post)
  end

  it "returns no markup on pages that aren't topics" do
    expect(described_class.build(nil)).to be_nil
  end

  it "returns no markup when post events are disabled" do
    SiteSetting.discourse_post_event_enabled = false

    expect(described_class.build(topic_view(event_double))).to be_nil
  end

  it "returns no markup when the setting is disabled" do
    SiteSetting.enable_event_schema_for_topics = false

    expect(described_class.build(topic_view(event_double))).to be_nil
  end

  it "returns no markup for an ordinary topic" do
    topic = instance_double(Topic, first_post: instance_double(Post, event: nil))

    expect(described_class.build(Struct.new(:topic, :posts).new(topic, nil))).to be_nil
  end

  it "safely embeds JSON in the script element" do
    name = "Community meetup </script><script>alert('hello')</script>"
    html = described_class.build(topic_view(event_double(name:)))
    fragment = Nokogiri::HTML5.fragment(html)

    expect(fragment.css('script[type="application/ld+json"]').count).to eq(1)
    expect(schema_from(html)["name"]).to eq(name)
  end

  def event_double(overrides = {})
    defaults = {
      all_day: false,
      deleted_at: nil,
      description: nil,
      image_upload: nil,
      starts_at: nil,
      ends_at: nil,
      location: nil,
      name: nil,
      post: nil,
      timezone: "UTC",
      url: "https://meet.example.com/hangout",
    }
    instance_double(DiscourseEvents::Events::Event, **defaults.merge(overrides))
  end

  def topic_view(event, image_upload_id: nil, image_url: nil)
    topic =
      instance_double(
        Topic,
        first_post: instance_double(Post, event:),
        image_upload_id:,
        image_url:,
        title: "Community hangout",
        url: "https://test.localhost/t/community-hangout/123",
      )
    Struct.new(:topic, :posts).new(topic, nil)
  end

  def schema_from(html)
    JSON.parse(Nokogiri::HTML5.fragment(html).at_css('script[type="application/ld+json"]').text)
  end
end
