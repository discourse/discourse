# frozen_string_literal: true

RSpec.describe TopicViewSerializer do
  subject(:serializer) do
    described_class.new(TopicView.new(topic), scope: Guardian.new, root: false)
  end

  let(:topic) { Fabricate(:topic) }
  let(:first_post) { Fabricate(:post, topic:) }
  let(:parsed_json) { JSON.parse(serializer.to_json) }

  before do
    freeze_time(Time.utc(2020, 4, 24, 14, 10))
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  context "without timezone" do
    before do
      DiscoursePostEvent::Event.create!(
        id: first_post.id,
        original_starts_at: 1.hour.from_now,
        original_ends_at: 2.hours.from_now,
      )
    end

    describe "#event_starts_at" do
      it "returns the start time of the event in proper format" do
        expect(parsed_json["event_starts_at"]).to eq("2020-04-24T15:10:00.000Z")
      end
    end

    describe "#event_ends_at" do
      it "returns the end time of the event in proper format" do
        expect(parsed_json["event_ends_at"]).to eq("2020-04-24T16:10:00.000Z")
      end
    end

    describe "#event_timezone" do
      it "is not included when event has no timezone" do
        expect(parsed_json).not_to have_key("event_timezone")
      end
    end

    describe "#event_show_local_time" do
      it "returns false when show_local_time is not set" do
        expect(parsed_json["event_show_local_time"]).to eq(false)
      end
    end
  end

  context "with timezone and show_local_time true" do
    before do
      DiscoursePostEvent::Event.create!(
        id: first_post.id,
        original_starts_at: 1.hour.from_now,
        original_ends_at: 2.hours.from_now,
        timezone: "Australia/Sydney",
        show_local_time: true,
      )
    end

    describe "#event_timezone" do
      it "returns the timezone of the event" do
        expect(parsed_json["event_timezone"]).to eq("Australia/Sydney")
      end
    end

    describe "#event_show_local_time" do
      it "returns true when show_local_time is set" do
        expect(parsed_json["event_show_local_time"]).to eq(true)
      end
    end
  end

  context "with timezone and show_local_time false" do
    before do
      DiscoursePostEvent::Event.create!(
        id: first_post.id,
        original_starts_at: 1.hour.from_now,
        original_ends_at: 2.hours.from_now,
        timezone: "Australia/Sydney",
        show_local_time: false,
      )
    end

    describe "#event_timezone" do
      it "returns the timezone of the event" do
        expect(parsed_json["event_timezone"]).to eq("Australia/Sydney")
      end
    end

    describe "#event_show_local_time" do
      it "returns false when show_local_time is explicitly false" do
        expect(parsed_json["event_show_local_time"]).to eq(false)
      end
    end
  end

  context "with all-day event" do
    before do
      SiteSetting.display_post_event_date_on_topic_title = true
      DiscoursePostEvent::Event.create!(
        id: first_post.id,
        original_starts_at: Time.utc(2020, 4, 25),
        original_ends_at: Time.utc(2020, 4, 27),
        all_day: true,
      )
    end

    describe "#event_all_day" do
      it "returns true" do
        expect(parsed_json["event_all_day"]).to eq(true)
      end
    end
  end

  context "without all-day event" do
    before do
      DiscoursePostEvent::Event.create!(
        id: first_post.id,
        original_starts_at: 1.hour.from_now,
        original_ends_at: 2.hours.from_now,
      )
    end

    describe "#event_all_day" do
      it "is not included" do
        expect(parsed_json).not_to have_key("event_all_day")
      end
    end
  end

  describe "#chat_channel_id" do
    fab!(:category)
    let(:topic) { Fabricate(:topic, category:) }

    before do
      SiteSetting.chat_enabled = true
      # Don't do onebox-warming job so it doesn't make a real request
      Jobs.run_later!
      first_post
    end

    def create_event(livestream:)
      DiscoursePostEvent::Event.create!(
        id: first_post.id,
        original_starts_at: 1.hour.from_now,
        original_ends_at: 2.hours.from_now,
        location: "https://example.com/live",
        livestream:,
      )
    end

    it "is included while the event is a livestream" do
      create_event(livestream: true)

      expect(topic.topic_chat_channel).to be_present
      expect(parsed_json["chat_channel_id"]).to eq(topic.topic_chat_channel.chat_channel_id)
    end

    it "is not included once livestream is disabled, even if the channel row remains" do
      event = create_event(livestream: true)
      event.update!(livestream: false)

      expect(topic.reload.topic_chat_channel).to be_present
      expect(parsed_json).not_to have_key("chat_channel_id")
    end
  end
end
