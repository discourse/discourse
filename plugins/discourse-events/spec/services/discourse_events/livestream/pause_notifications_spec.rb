# frozen_string_literal: true

RSpec.describe DiscourseEvents::Livestream::PauseNotifications do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:pause_key) }
    it { is_expected.to allow_value(SecureRandom.uuid).for(:pause_key) }
    it { is_expected.not_to allow_value("not-a-key").for(:pause_key) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :user)
    fab!(:post) { Fabricate(:post, post_number: 1) }
    fab!(:event) do
      Fabricate(:event, post:, original_starts_at: 5.minutes.ago, original_ends_at: 1.hour.from_now)
    end

    let(:params) { { topic_id:, pause_key: } }
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:topic_id) { post.topic_id }
    let(:pause_key) { SecureRandom.uuid }

    context "when the contract is invalid" do
      let(:pause_key) { "not-a-key" }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:topic_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the user cannot see the topic" do
      before do
        post.topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))
      end

      it { is_expected.to fail_a_policy(:can_see_topic) }
    end

    context "when the topic has no event" do
      let(:topic_id) { Fabricate(:post, post_number: 1).topic_id }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "when the event is over" do
      before { event.event_dates.update_all(starts_at: 2.hours.ago, ends_at: 1.hour.ago) }

      it { is_expected.to fail_a_policy(:event_not_over) }
    end

    context "when the pause was ended before it was started" do
      before do
        DiscourseEvents::Livestream::ResumeNotifications.call(
          params: {
            pause_key:,
          },
          **dependencies,
        )
      end

      it { is_expected.to fail_to_find_a_model(:do_not_disturb_timing) }

      it "does not pause notifications" do
        expect { result }.not_to change { current_user.do_not_disturb? }.from(false)
      end
    end

    context "when everything's ok" do
      let(:messages) { MessageBus.track_publish("/do-not-disturb/#{current_user.id}") { result } }

      it { is_expected.to run_successfully }

      it "pauses notifications until the event ends" do
        result
        expect(current_user.do_not_disturb_until).to eq_time(event.ends_at)
      end

      it "announces the pause to the user" do
        expect(messages.map(&:data)).to contain_exactly({ ends_at: event.ends_at.httpdate })
      end
    end
  end
end
