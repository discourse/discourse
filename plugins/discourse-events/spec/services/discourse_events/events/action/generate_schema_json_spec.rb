# frozen_string_literal: true

RSpec.describe DiscourseEvents::Events::Action::GenerateSchemaJson do
  describe ".call" do
    subject(:schema) { JSON.parse(described_class.call(topic:, first_post:, event:)) }

    fab!(:user)
    fab!(:topic) { Fabricate(:topic_with_op, user:, title: "Community hangout") }
    fab!(:event) do
      Fabricate(
        :event,
        post: topic.first_post,
        name: "Community hangout",
        description: "[Meet the community](https://example.com)",
        original_starts_at: Time.iso8601("2026-10-22T13:00:00Z"),
        original_ends_at: Time.iso8601("2026-10-22T14:00:00Z"),
        timezone: "America/New_York",
        url: "https://meet.example.com/hangout",
      )
    end

    let(:first_post) { topic.first_post }

    it "generates the complete Schema.org Event document" do
      expect(schema).to include(
        "@context" => "https://schema.org",
        "@type" => "Event",
        "name" => "Community hangout",
        "description" => "Meet the community",
        "startDate" => "2026-10-22T09:00:00.000-04:00",
        "endDate" => "2026-10-22T10:00:00.000-04:00",
        "eventStatus" => "https://schema.org/EventScheduled",
        "eventAttendanceMode" => "https://schema.org/OnlineEventAttendanceMode",
        "location" => {
          "@type" => "VirtualLocation",
          "url" => "https://meet.example.com/hangout",
        },
        "url" => topic.url,
      )
    end

    it "uses the topic title when the event has no name" do
      event.update!(name: nil)

      expect(schema["name"]).to eq(topic.title)
    end

    it "cooks the description to plain text" do
      event.update!(description: "Meet [the community](https://example.com) today")

      expect(schema["description"]).to eq("Meet the community today")
    end

    it "returns unsafe strings as JSON data" do
      unsafe_name = "Community meetup </script><script>alert('hello')</script>"
      event.update!(name: unsafe_name)

      expect(schema["name"]).to eq(unsafe_name)
    end

    it "keeps all-day event dates independent of positive and negative UTC offsets" do
      event.update!(
        all_day: true,
        original_starts_at: Time.utc(2026, 10, 22),
        original_ends_at: Time.utc(2026, 10, 23, 23, 59, 59),
      )

      %w[America/New_York Pacific/Kiritimati].each do |timezone|
        event.update!(timezone:)
        generated_schema = JSON.parse(described_class.call(topic:, first_post:, event:))

        expect(generated_schema).to include("startDate" => "2026-10-22", "endDate" => "2026-10-23")
      end
    end

    context "with a physical location" do
      before { event.update!(location: "[Town hall](https://example.com/hall)", url: nil) }

      it "generates offline event data" do
        expect(schema).to include(
          "eventAttendanceMode" => "https://schema.org/OfflineEventAttendanceMode",
          "location" => {
            "@type" => "Place",
            "name" => "Town hall",
            "address" => "Town hall",
          },
        )
      end
    end

    context "with physical and virtual locations" do
      before { event.update!(location: "Town hall") }

      it "generates mixed event data" do
        expect(schema["eventAttendanceMode"]).to eq("https://schema.org/MixedEventAttendanceMode")
        expect(schema["location"].map { |location| location["@type"] }).to eq(
          %w[Place VirtualLocation],
        )
      end
    end

    context "with the same stream URL as its location and event URL" do
      before do
        event.update!(
          location: "https://stream.example.com/live",
          url: "https://stream.example.com/live",
        )
      end

      it "generates one virtual location" do
        expect(schema).to include(
          "eventAttendanceMode" => "https://schema.org/OnlineEventAttendanceMode",
          "location" => {
            "@type" => "VirtualLocation",
            "url" => "https://stream.example.com/live",
          },
        )
      end
    end

    context "with an invalid event URL" do
      before do
        event.update!(location: "Town hall")
        event.update_column(:url, "javascript:alert(1)")
      end

      it "omits the invalid virtual location" do
        expect(schema).to include(
          "eventAttendanceMode" => "https://schema.org/OfflineEventAttendanceMode",
          "location" => {
            "@type" => "Place",
            "name" => "Town hall",
            "address" => "Town hall",
          },
        )
      end
    end

    context "without an event location or URL" do
      before { event.update!(location: nil, url: nil) }

      it "uses the topic as a virtual location" do
        expect(schema).to include(
          "eventAttendanceMode" => "https://schema.org/OnlineEventAttendanceMode",
          "location" => {
            "@type" => "VirtualLocation",
            "url" => topic.url,
          },
        )
      end
    end

    context "with an event image synced to the topic" do
      fab!(:upload) { Fabricate(:upload, width: 800, height: 1200) }

      before do
        event.update!(image_upload: upload)
        topic.update!(image_upload_id: upload.id)
      end

      it "uses the topic image URL" do
        expect(schema["image"]).to eq(
          "@type" => "ImageObject",
          "url" => ApplicationController.helpers.get_absolute_image_url(topic.reload.image_url),
          "width" => 800,
          "height" => 1200,
        )
      end
    end

    context "with an event image that differs from the topic image" do
      fab!(:upload) { Fabricate(:upload, width: 800, height: 1200) }

      before { event.update!(image_upload: upload) }

      it "uses the event upload URL" do
        expect(schema["image"]).to eq(
          "@type" => "ImageObject",
          "url" => ApplicationController.helpers.get_absolute_image_url(upload.url),
          "width" => 800,
          "height" => 1200,
        )
      end
    end

    context "with a secure event image" do
      fab!(:secure_upload) { Fabricate(:secure_upload, width: 800, height: 1200) }

      before { event.update!(image_upload: secure_upload) }

      it "omits the image" do
        expect(schema).not_to have_key("image")
      end
    end

    context "without an event image" do
      it "omits the image" do
        expect(schema).not_to have_key("image")
      end
    end

    it "omits the schedule for a one-off event" do
      expect(schema).not_to have_key("eventSchedule")
    end

    context "with a recurring event" do
      before { freeze_time Time.utc(2026, 10, 1) }

      it "describes a weekly recurrence on the event's local weekday" do
        # 01:00 UTC on Friday is still Thursday evening in New York
        event.update!(
          recurrence: "every_week",
          original_starts_at: Time.iso8601("2026-10-23T01:00:00Z"),
          original_ends_at: Time.iso8601("2026-10-23T02:00:00Z"),
          recurrence_until: Time.iso8601("2026-12-31T23:59:00-05:00"),
        )

        expect(schema["eventSchedule"]).to eq(
          "@type" => "Schedule",
          "repeatFrequency" => "P1W",
          "byDay" => "https://schema.org/Thursday",
          "endDate" => "2026-12-31",
          "scheduleTimezone" => "America/New_York",
        )
      end

      it "describes the weekdays of a weekday recurrence" do
        event.update!(recurrence: "every_weekday")

        expect(schema["eventSchedule"]).to include(
          "repeatFrequency" => "P1D",
          "byDay" =>
            %w[Monday Tuesday Wednesday Thursday Friday].map { "https://schema.org/#{it}" },
        )
      end

      it "describes the week of the month for a monthly recurrence" do
        event.update!(recurrence: "every_month")

        expect(schema["eventSchedule"]).to include(
          "repeatFrequency" => "P1M",
          "byDay" => "https://schema.org/Thursday",
          "byMonthWeek" => 4,
        )
      end

      it "describes a fifth weekday as the last of the month" do
        event.update!(
          recurrence: "every_month",
          original_starts_at: Time.iso8601("2026-10-29T13:00:00Z"),
          original_ends_at: Time.iso8601("2026-10-29T14:00:00Z"),
        )

        expect(schema["eventSchedule"]).to include("byMonthWeek" => -1)
      end

      it "takes the week of the month from the start of the series" do
        # The series runs on the last Thursday, even when the current one is also the fourth
        event.update!(
          recurrence: "every_month",
          original_starts_at: Time.iso8601("2026-10-29T13:00:00Z"),
          original_ends_at: Time.iso8601("2026-10-29T14:00:00Z"),
        )
        event.event_dates.create!(
          starts_at: Time.iso8601("2026-11-26T14:00:00Z"),
          ends_at: Time.iso8601("2026-11-26T15:00:00Z"),
        )

        expect(schema).to include("startDate" => "2026-11-26T09:00:00.000-05:00")
        expect(schema["eventSchedule"]).to include("byMonthWeek" => -1)
      end

      it "describes multi-week intervals" do
        event.update!(recurrence: "every_two_weeks")
        expect(schema["eventSchedule"]).to include("repeatFrequency" => "P2W")

        event.update!(recurrence: "every_four_weeks")
        expect(
          JSON.parse(described_class.call(topic:, first_post:, event:))["eventSchedule"],
        ).to include("repeatFrequency" => "P4W")
      end
    end
  end
end
