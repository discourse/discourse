# frozen_string_literal: true

RSpec.describe TopicsFilter do
  fab!(:plain_topic, :topic)
  fab!(:upcoming_event) do
    Fabricate(
      :event,
      original_starts_at: 3.days.from_now,
      original_ends_at: 3.days.from_now + 1.hour,
    )
  end
  fab!(:ongoing_event) do
    Fabricate(:event, original_starts_at: 1.hour.ago, original_ends_at: 1.hour.from_now)
  end
  fab!(:past_event) do
    Fabricate(:event, original_starts_at: 3.days.ago, original_ends_at: 3.days.ago + 1.hour)
  end

  let(:upcoming_topic) { upcoming_event.post.topic }
  let(:ongoing_topic) { ongoing_event.post.topic }
  let(:past_topic) { past_event.post.topic }
  let(:fixture_topic_ids) { [plain_topic.id, upcoming_topic.id, ongoing_topic.id, past_topic.id] }

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  def filtered_topic_ids(query_string, user: nil)
    TopicsFilter
      .new(guardian: Guardian.new(user))
      .filter_from_query_string(query_string)
      .pluck(:id) & fixture_topic_ids
  end

  describe "event:" do
    it "matches topics by event state" do
      expect(filtered_topic_ids("event:any")).to contain_exactly(
        upcoming_topic.id,
        ongoing_topic.id,
        past_topic.id,
      )
      expect(filtered_topic_ids("event:upcoming")).to contain_exactly(upcoming_topic.id)
      expect(filtered_topic_ids("event:ongoing")).to contain_exactly(ongoing_topic.id)
      expect(filtered_topic_ids("event:past")).to contain_exactly(past_topic.id)
      expect(filtered_topic_ids("event:upcoming,ongoing")).to contain_exactly(
        upcoming_topic.id,
        ongoing_topic.id,
      )
    end

    it "excludes topics with events when negated" do
      expect(filtered_topic_ids("-event:any")).to contain_exactly(plain_topic.id)
      expect(filtered_topic_ids("-event:past")).to contain_exactly(
        plain_topic.id,
        upcoming_topic.id,
        ongoing_topic.id,
      )
    end

    it "treats closed events as past" do
      upcoming_event.update_columns(closed: true)

      expect(filtered_topic_ids("event:past")).to contain_exactly(upcoming_topic.id, past_topic.id)
    end

    it "ignores events that have been deleted" do
      upcoming_event.update_columns(deleted_at: Time.current)

      expect(filtered_topic_ids("event:any")).to contain_exactly(ongoing_topic.id, past_topic.id)
    end

    it "ignores unknown states" do
      expect(filtered_topic_ids("event:someday")).to match_array(fixture_topic_ids)
    end

    it "does nothing when events are disabled" do
      SiteSetting.discourse_post_event_enabled = false

      expect(filtered_topic_ids("event:upcoming")).to match_array(fixture_topic_ids)
    end
  end

  describe "event-after: and event-before:" do
    it "matches topics by event start date" do
      expect(filtered_topic_ids("event-after:#{1.day.from_now.to_date}")).to contain_exactly(
        upcoming_topic.id,
      )
      expect(
        filtered_topic_ids("event-before:#{ongoing_event.original_starts_at.to_date}"),
      ).to contain_exactly(past_topic.id)
      expect(
        filtered_topic_ids(
          "event-after:#{2.days.ago.to_date} event-before:#{1.day.from_now.to_date}",
        ),
      ).to contain_exactly(ongoing_topic.id)
    end

    it "ignores values that are not dates" do
      expect(filtered_topic_ids("event-after:7")).to match_array(fixture_topic_ids)
    end
  end

  describe "event-attending:" do
    fab!(:attendee, :user)
    fab!(:viewer, :user)
    fab!(:invited_group) { Fabricate(:group, users: [attendee]) }
    fab!(:private_event) do
      Fabricate(
        :event,
        status: DiscourseEvents::Events::Event.statuses[:private],
        raw_invitees: [invited_group.name],
      )
    end

    before do
      Fabricate(
        :post_event_invitee,
        event: upcoming_event,
        user: attendee,
        status: DiscourseEvents::Events::Invitee.statuses[:going],
      )
      Fabricate(
        :post_event_invitee,
        event: past_event,
        user: attendee,
        status: DiscourseEvents::Events::Invitee.statuses[:interested],
      )
      Fabricate(
        :post_event_invitee,
        event: private_event,
        user: attendee,
        status: DiscourseEvents::Events::Invitee.statuses[:going],
      )
      fixture_topic_ids << private_event.post.topic.id
    end

    it "matches events the user is going to" do
      expect(
        filtered_topic_ids("event-attending:#{attendee.username}", user: viewer),
      ).to contain_exactly(upcoming_topic.id)
    end

    it "includes private events for members of an invited group" do
      expect(filtered_topic_ids("event-attending:me", user: attendee)).to contain_exactly(
        upcoming_topic.id,
        private_event.post.topic.id,
      )
    end

    it "matches nothing for anonymous users asking for their own events" do
      expect(filtered_topic_ids("event-attending:me")).to be_empty
    end
  end

  describe "order:event-start" do
    it "sorts topics by event start date" do
      ids = ->(query) { filtered_topic_ids(query) - [plain_topic.id] }

      expect(ids.call("order:event-start")).to eq(
        [upcoming_topic.id, ongoing_topic.id, past_topic.id],
      )
      expect(ids.call("order:event-start-asc")).to eq(
        [past_topic.id, ongoing_topic.id, upcoming_topic.id],
      )
    end
  end

  describe ".option_info" do
    it "includes the event filters" do
      names = described_class.option_info(Guardian.new).map { |option| option[:name] }

      expect(names).to include(
        "event:",
        "event:upcoming",
        "event-after:",
        "event-attending:",
        "order:event-start",
        "order:event-start-asc",
      )
    end
  end
end
