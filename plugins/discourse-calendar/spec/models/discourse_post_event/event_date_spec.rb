# frozen_string_literal: true

describe DiscoursePostEvent::EventDate do
  let(:user) { Fabricate(:user, admin: true) }
  let(:topic) { Fabricate(:topic, user: user) }
  let!(:first_post) { Fabricate(:post, topic: topic) }
  let!(:second_post) { Fabricate(:post, topic: topic) }
  let!(:starts_at) { "2020-04-24 08:15:00" }
  let!(:starts_at_yesterday) { "2020-04-23 19:15:00" }
  let!(:post_event) { Fabricate(:event, post: first_post, original_starts_at: starts_at) }
  let!(:yesterday_post_event) do
    Fabricate(:event, post: second_post, original_starts_at: starts_at_yesterday)
  end

  before do
    freeze_time DateTime.parse("2020-04-24 14:10")
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe "Event Date Ended?" do
    context "with no end date time" do
      it "returns false if started today" do
        expect(post_event.event_dates.count).to eq(1)
        event_date = post_event.event_dates.last
        expect(event_date.ended?).to eq(false)
      end

      it "returns true if started before today" do
        expect(yesterday_post_event.event_dates.count).to eq(1)
        yesterday_event_date = yesterday_post_event.event_dates.last
        expect(yesterday_event_date.ended?).to eq(true)
      end
    end
  end

  describe "Topic custom fields" do
    it "writes TopicEventAllDay custom field for all-day events" do
      all_day_post = Fabricate(:post, topic: Fabricate(:topic, user: user))
      event =
        Fabricate(
          :event,
          post: all_day_post,
          original_starts_at: "2020-04-25 00:00:00 UTC",
          original_ends_at: "2020-04-27 00:00:00 UTC",
          all_day: true,
        )

      custom_field =
        TopicCustomField.find_by(
          topic_id: all_day_post.topic_id,
          name: DiscoursePostEvent::TOPIC_POST_EVENT_ALL_DAY,
        )

      expect(custom_field).to be_present
      expect(custom_field.value).to eq("t")
    end

    it "writes false for non-all-day events" do
      custom_field =
        TopicCustomField.find_by(
          topic_id: first_post.topic_id,
          name: DiscoursePostEvent::TOPIC_POST_EVENT_ALL_DAY,
        )

      expect(custom_field).to be_present
      expect(custom_field.value).to eq("f")
    end
  end
end
