# frozen_string_literal: true

RSpec.describe DiscourseEvents::Events::Event::SyncFromPost do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author) { Fabricate(:user, admin: true, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic, user: author) }
    fab!(:post) { Fabricate(:post, topic:, user: author) }

    let(:params) { { post_id: } }
    let(:dependencies) { {} }
    let(:post_id) { post.id }
    let(:raw_event) do
      { name: "My event", start: "2030-04-24 14:15", timezone: "UTC", status: "public" }
    end

    before do
      SiteSetting.discourse_events_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      Jobs.run_immediately!

      DiscourseEvents::Events::Parser.stubs(:extract_events).returns([raw_event])
    end

    context "when the contract is invalid" do
      let(:post_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the post is not found" do
      let(:post_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when the raw has an event and the post has none" do
      it { is_expected.to run_successfully }

      it "creates the event from the raw" do
        expect { result }.to change { DiscourseEvents::Events::Event.count }.by(1)

        event = post.reload.event
        expect(event.original_starts_at).to eq_time(Time.utc(2030, 4, 24, 14, 15))
        expect(event.status).to eq(DiscourseEvents::Events::Event.statuses[:public])
        expect(event.name).to eq("My event")
      end

      it "reconciles invitees through update_with_params! (public status)" do
        result
        expect(post.reload.event.raw_invitees).to eq([DiscourseEvents::Events::Event::PUBLIC_GROUP])
      end

      it "publishes the event update" do
        messages = MessageBus.track_publish("/discourse-post-event/#{topic.id}") { result }
        expect(messages.map { |m| m.data[:id] }).to include(post.id)
      end
    end

    context "when the raw has an event and the post already has one" do
      fab!(:event) { Fabricate(:event, post:, original_starts_at: "2020-01-01 10:00") }

      it { is_expected.to run_successfully }

      it "updates the existing event" do
        expect { result }.to change { post.reload.event.reload.original_starts_at }.to(
          Time.utc(2030, 4, 24, 14, 15),
        )
      end
    end

    context "when the synced event is standalone" do
      fab!(:event) do
        Fabricate(:event, post:, status: DiscourseEvents::Events::Event.statuses[:standalone])
      end
      fab!(:invitee) { Fabricate(:post_event_invitee, event:, user: Fabricate(:user)) }

      let(:raw_event) { { name: "My event", start: "2030-04-24 14:15", timezone: "UTC" } }

      it { is_expected.to run_successfully }

      it "destroys the event's invitees" do
        expect { result }.to change { DiscourseEvents::Events::Invitee.count }.by(-1)
      end
    end

    context "when the raw has no event but the post has one" do
      fab!(:event) { Fabricate(:event, post:) }

      before { DiscourseEvents::Events::Parser.stubs(:extract_events).returns([]) }

      it { is_expected.to run_successfully }

      it "removes the event" do
        expect { result }.to change { DiscourseEvents::Events::Event.count }.by(-1)
        expect(post.reload.event).to be_nil
      end
    end

    context "when the raw has no event and the post has none" do
      before { DiscourseEvents::Events::Parser.stubs(:extract_events).returns([]) }

      it { is_expected.to run_successfully }

      it "does not create an event" do
        expect { result }.not_to change { DiscourseEvents::Events::Event.count }
      end
    end

    context "when the parsed event is invalid downstream of the contract" do
      let(:raw_event) do
        {
          name: "My event",
          start: "2030-04-24 14:15",
          timezone: "UTC",
          status: "public",
          "max-attendees": "0",
        }
      end

      it { is_expected.to fail_with_an_invalid_model(:event) }

      it "exposes the invalid event and its errors" do
        expect(result[:event].errors[:max_attendees]).to be_present
      end

      it "does not persist the event" do
        expect { result }.not_to change { DiscourseEvents::Events::Event.count }
      end
    end
  end
end
