# frozen_string_literal: true

RSpec.describe TopicListItemSerializer do
  subject(:serializer) { described_class.new(topic, scope: Guardian.new, root: false) }

  let(:topic) { Fabricate(:topic) }
  let(:first_post) { Fabricate(:post, topic:) }
  let(:parsed_json) { JSON.parse(serializer.to_json) }

  before do
    freeze_time("2020-04-24 14:10")
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
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
end
