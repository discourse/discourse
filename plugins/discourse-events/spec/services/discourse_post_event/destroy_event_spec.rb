# frozen_string_literal: true

RSpec.describe(DiscoursePostEvent::DestroyEvent) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:event_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin, :admin)
    fab!(:topic) { Fabricate(:topic, user: admin) }
    fab!(:post) { Fabricate(:post, user: admin, topic: topic) }
    fab!(:event) { Fabricate(:event, post: post) }

    let(:params) { { event_id: event.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    before do
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
    end

    context "when contract is invalid" do
      let(:params) { { event_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when event does not exist" do
      let(:params) { { event_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "when user cannot act on the event" do
      fab!(:other_user, :user)
      let(:dependencies) { { guardian: other_user.guardian } }

      it { is_expected.to fail_a_policy(:can_act_on_event) }
    end

    context "when everything is valid" do
      let(:messages) { MessageBus.track_publish("/discourse-post-event/#{topic.id}") { result } }

      it { is_expected.to run_successfully }

      it "destroys the event" do
        expect { result }.to change { DiscoursePostEvent::Event.count }.by(-1)
        expect(DiscoursePostEvent::Event.exists?(event.id)).to eq(false)
      end

      it "publishes an event update" do
        expect(messages.size).to eq(1)
        expect(messages.first.data[:id]).to eq(event.id)
      end

      it "enqueues the destroyed web hook event" do
        Jobs.run_later!
        Fabricate(:outgoing_calendar_event_web_hook)

        expect { result }.to change { Jobs::EmitWebHookEvent.jobs.size }.by(1)
        job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
        expect(job_args["event_name"]).to eq("calendar_event_destroyed")
      end
    end
  end
end
