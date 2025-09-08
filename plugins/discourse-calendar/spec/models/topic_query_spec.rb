# frozen_string_literal: true

describe TopicQuery do
  describe "sorts events" do
    fab!(:user) { Fabricate(:user, admin: true) }
    fab!(:notified_user) { Fabricate(:user) }
    fab!(:topic_1) { Fabricate(:topic, user: user) }
    fab!(:topic_2) { Fabricate(:topic, user: user) }
    fab!(:topic_3) { Fabricate(:topic, user: user) }
    fab!(:topic_4) { Fabricate(:topic, user: user) }
    fab!(:post_1) { Fabricate(:post, topic: topic_1) }
    fab!(:post_2) { Fabricate(:post, topic: topic_2) }
    fab!(:post_3) { Fabricate(:post, topic: topic_3) }
    fab!(:post_4) { Fabricate(:post, topic: topic_4) }

    fab!(:future_event_1) do
      DiscoursePostEvent::Event.create!(
        id: post_1.id,
        original_starts_at: Time.now + 5.hours,
        original_ends_at: Time.now + 7.hours,
      )
    end
    fab!(:future_event_2) do
      DiscoursePostEvent::Event.create!(
        id: post_2.id,
        original_starts_at: Time.now + 1.hours,
        original_ends_at: Time.now + 2.hours,
      )
    end
    fab!(:past_event_1) do
      DiscoursePostEvent::Event.create!(
        id: post_3.id,
        original_starts_at: Time.now - 10.hours,
        original_ends_at: Time.now - 8.hours,
      )
    end
    fab!(:past_event_2) do
      DiscoursePostEvent::Event.create!(
        id: post_4.id,
        original_starts_at: Time.now - 7.hours,
        original_ends_at: Time.now - 5.hours,
      )
    end

    it "upcoming events first, sorted by ascending order. expired events last, sorted by descending order" do
      ordered_topics =
        TopicQuery.new(nil, order_by_event_date: [topic_1, topic_2, topic_3, topic_4]).options[
          :order_by_event_date
        ]
      expect(ordered_topics).to eq([topic_1, topic_2, topic_3, topic_4])
    end
  end
end
