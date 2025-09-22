# frozen_string_literal: true

describe DiscoursePostEvent::EventSerializer do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  context "with a private event" do
    fab!(:private_event) do
      Fabricate(:event, post: post, status: DiscoursePostEvent::Event.statuses[:private])
    end

    fab!(:invitee_1) { Fabricate(:user) }
    fab!(:invitee_2) { Fabricate(:user) }
    fab!(:group_1) do
      Fabricate(:group).tap do |g|
        g.add(invitee_1)
        g.add(invitee_2)
        g.save!
      end
    end

    context "when some invited users have not rsvp-ed yet" do
      before do
        private_event.update_with_params!(raw_invitees: [group_1.name])
        DiscoursePostEvent::Invitee.create_attendance!(invitee_1.id, private_event.id, :going)
        private_event.reload
      end

      it "returns the correct stats" do
        json = DiscoursePostEvent::EventSerializer.new(private_event, scope: Guardian.new).as_json
        expect(json[:event][:stats]).to eq(
          going: 1,
          interested: 0,
          invited: 2,
          not_going: 0,
          capacity: nil,
        )
      end
    end
  end

  context "with a public event" do
    fab!(:event) { Fabricate(:event, post: post) }

    it "returns the event category's id" do
      json = DiscoursePostEvent::EventSerializer.new(event, scope: Guardian.new).as_json
      expect(json[:event][:category_id]).to eq(category.id)
    end

    context "when event has duration" do
      fab!(:post_with_duration) { Fabricate(:post, topic: topic) }
      fab!(:event_with_duration) do
        Fabricate(
          :event,
          post: post_with_duration,
          original_starts_at: "2022-01-15 10:00:00 UTC",
          original_ends_at: "2022-01-15 11:30:00 UTC",
        )
      end

      it "includes duration in serialized output" do
        json =
          DiscoursePostEvent::EventSerializer.new(event_with_duration, scope: Guardian.new).as_json
        expect(json[:event][:duration]).to eq("01:30:00")
      end
    end

    context "when event has no end time" do
      fab!(:post_no_end) { Fabricate(:post, topic: topic) }
      fab!(:event_no_end) do
        Fabricate(
          :event,
          post: post_no_end,
          original_starts_at: "2022-01-15 10:00:00 UTC",
          original_ends_at: nil,
        )
      end

      it "includes default 1-hour duration in serialized output" do
        json = DiscoursePostEvent::EventSerializer.new(event_no_end, scope: Guardian.new).as_json
        expect(json[:event]).to have_key(:duration)
        expect(json[:event][:duration]).to eq("01:00:00")
      end
    end
  end
end
