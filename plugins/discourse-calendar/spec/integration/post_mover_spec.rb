# frozen_string_literal: true

RSpec.describe PostMover do
  fab!(:admin)
  fab!(:user1, :user)
  fab!(:user2, :user)

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe "moving posts with calendar events" do
    fab!(:original_topic) { Fabricate(:topic, user: admin) }
    fab!(:destination_topic) { Fabricate(:topic, user: admin) }
    fab!(:op) { Fabricate(:post, topic: original_topic, user: admin) }

    fab!(:calendar_event) do
      Fabricate(:calendar_event, post: op, topic: original_topic, user: admin)
    end

    it "moves calendar events when post_id changes" do
      new_post = Fabricate(:post, topic: destination_topic, user: admin)
      DiscourseEvent.trigger(:post_moved, new_post, original_topic.id, op)

      expect(CalendarEvent.where(post_id: new_post.id).count).to eq(1)
      expect(CalendarEvent.where(post_id: op.id).count).to eq(0)
    end

    it "does not change data when post_id stays the same" do
      DiscourseEvent.trigger(:post_moved, op, original_topic.id, op)

      expect(CalendarEvent.where(post_id: op.id).count).to eq(1)
    end
  end

  describe "moving posts with post events" do
    fab!(:original_topic) { Fabricate(:topic, user: admin) }
    fab!(:destination_topic) { Fabricate(:topic, user: admin) }
    fab!(:op) { Fabricate(:post, topic: original_topic, user: admin) }

    fab!(:event) { Fabricate(:event, post: op) }

    before do
      DiscoursePostEvent::Invitee.create!(post_id: event.id, user_id: user1.id, status: 0)
      DiscoursePostEvent::Invitee.create!(post_id: event.id, user_id: user2.id, status: 1)
    end

    it "moves event, invitees, and event dates when post_id changes" do
      expect(DiscoursePostEvent::EventDate.where(event_id: op.id).count).to eq(1)

      new_post = Fabricate(:post, topic: destination_topic, user: admin)
      DiscourseEvent.trigger(:post_moved, new_post, original_topic.id, op)

      expect(DiscoursePostEvent::Event.exists?(id: new_post.id)).to eq(true)
      expect(DiscoursePostEvent::Event.exists?(id: op.id)).to eq(false)

      expect(DiscoursePostEvent::Invitee.unscoped.where(post_id: new_post.id).count).to eq(2)
      expect(DiscoursePostEvent::Invitee.unscoped.where(post_id: op.id).count).to eq(0)

      expect(DiscoursePostEvent::EventDate.where(event_id: new_post.id).count).to eq(1)
      expect(DiscoursePostEvent::EventDate.where(event_id: op.id).count).to eq(0)
    end

    it "replaces duplicate event created by :post_created" do
      new_post = Fabricate(:post, topic: destination_topic, user: admin)
      # simulate what :post_created does before :post_moved fires
      DiscoursePostEvent::Event.create!(id: new_post.id, original_starts_at: 1.day.from_now)

      DiscourseEvent.trigger(:post_moved, new_post, original_topic.id, op)

      expect(DiscoursePostEvent::Event.where(id: new_post.id).count).to eq(1)
      expect(DiscoursePostEvent::Invitee.unscoped.where(post_id: new_post.id).count).to eq(2)
    end
  end
end
