# frozen_string_literal: true

RSpec.describe DiscourseCalendar::Livestream::ZoomLiveMeetings do
  let(:meeting_number) { "123456789" }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.livestream_zoom_enabled = true
  end

  describe ".live?" do
    it "follows the meeting from started to ended" do
      expect(described_class.live?(meeting_number)).to eq(false)

      described_class.started(meeting_number)

      expect(described_class.live?(meeting_number)).to eq(true)

      described_class.ended(meeting_number)

      expect(described_class.live?(meeting_number)).to eq(false)
    end

    it "is false for a blank meeting number" do
      expect(described_class.live?(nil)).to eq(false)
      expect(described_class.live?("")).to eq(false)
    end
  end

  describe ".events_for" do
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:event) do
      Fabricate(
        :event,
        post: post,
        livestream: true,
        location: "https://us06web.zoom.us/j/123456789?pwd=secret",
      )
    end

    # The livestream flag is only kept on a topic's first post, so every event
    # needs a topic of its own.
    def fabricate_livestream_event(location:, livestream: true)
      event_topic = Fabricate(:topic)
      event_post = Fabricate(:post, topic: event_topic, post_number: 1)
      Fabricate(:event, post: event_post, livestream: livestream, location: location)
    end

    it "is empty for a blank meeting number" do
      expect(described_class.events_for(nil)).to be_empty
      expect(described_class.events_for("")).to be_empty
    end

    it "returns the event whose Zoom URL carries the meeting number" do
      expect(described_class.events_for(meeting_number)).to contain_exactly(event)
    end

    it "ignores an event on a different Zoom meeting" do
      fabricate_livestream_event(location: "https://zoom.us/j/987654321")

      expect(described_class.events_for(meeting_number)).to contain_exactly(event)
    end

    it "ignores an event whose URL is not a Zoom URL" do
      fabricate_livestream_event(location: "https://example.com/j/#{meeting_number}")

      expect(described_class.events_for(meeting_number)).to contain_exactly(event)
    end

    it "ignores an event whose URL only mentions the number outside the meeting number" do
      fabricate_livestream_event(location: "https://us06web.zoom.us/j/999?pwd=a/#{meeting_number}")

      expect(described_class.events_for(meeting_number)).to contain_exactly(event)
    end

    it "ignores a deleted event" do
      deleted_event =
        fabricate_livestream_event(location: "https://zoom.us/j/#{meeting_number}?pwd=secret")
      deleted_event.update!(deleted_at: Time.current)

      expect(described_class.events_for(meeting_number)).to contain_exactly(event)
    end

    it "ignores an event that is not a livestream" do
      fabricate_livestream_event(location: "https://zoom.us/j/#{meeting_number}", livestream: false)

      expect(described_class.events_for(meeting_number)).to contain_exactly(event)
    end

    it "ignores an event whose topic is gone" do
      orphaned_event =
        fabricate_livestream_event(location: "https://zoom.us/j/#{meeting_number}?pwd=secret")
      orphaned_event.post.topic.delete

      expect(described_class.events_for(meeting_number)).to contain_exactly(event)
    end
  end
end
