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

    fab!(:invitee_1, :user)
    fab!(:invitee_2, :user)
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

    it "excludes image_upload when not set" do
      json = DiscoursePostEvent::EventSerializer.new(event, scope: Guardian.new).as_json
      expect(json[:event][:image_upload]).to be_nil
    end

    context "when event has an image" do
      fab!(:upload)
      fab!(:event_with_image) do
        Fabricate(:event, post: Fabricate(:post, topic: topic), image_upload: upload)
      end

      it "includes image_upload in serialized output" do
        json =
          DiscoursePostEvent::EventSerializer.new(event_with_image, scope: Guardian.new).as_json
        expect(json[:event][:image_upload][:id]).to eq(upload.id)
        expect(json[:event][:image_upload][:url]).to include(upload.url)
      end
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

    context "when event is all-day" do
      fab!(:post_all_day) { Fabricate(:post, topic: topic) }
      fab!(:all_day_event) do
        Fabricate(
          :event,
          post: post_all_day,
          original_starts_at: "2026-03-12 00:00:00 UTC",
          original_ends_at: "2026-03-14 00:00:00 UTC",
          all_day: true,
        )
      end

      it "serializes starts_at as date-only string" do
        json = DiscoursePostEvent::EventSerializer.new(all_day_event, scope: Guardian.new).as_json
        expect(json[:event][:starts_at]).to eq("2026-03-12")
      end

      it "serializes ends_at as date-only string" do
        json = DiscoursePostEvent::EventSerializer.new(all_day_event, scope: Guardian.new).as_json
        expect(json[:event][:ends_at]).to eq("2026-03-14")
      end

      it "serializes all_day as true" do
        json = DiscoursePostEvent::EventSerializer.new(all_day_event, scope: Guardian.new).as_json
        expect(json[:event][:all_day]).to eq(true)
      end
    end
  end
end
