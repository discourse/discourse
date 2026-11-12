# frozen_string_literal: true

RSpec.describe DiscourseEvents::Livestream::ResumeNotifications do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:pause_key) }
    it { is_expected.not_to allow_value("not-a-key").for(:pause_key) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :user)
    fab!(:post) { Fabricate(:post, post_number: 1) }
    fab!(:event) do
      Fabricate(:event, post:, original_starts_at: 5.minutes.ago, original_ends_at: 1.hour.from_now)
    end

    let(:params) { { pause_key: } }
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:pause_key) { SecureRandom.uuid }
    let(:messages) { MessageBus.track_publish("/do-not-disturb/#{current_user.id}") { result } }

    def start_pause(key)
      DiscourseEvents::Livestream::PauseNotifications.call(
        params: {
          topic_id: post.topic_id,
          pause_key: key,
        },
        **dependencies,
      )
    end

    context "when the contract is invalid" do
      let(:pause_key) { "not-a-key" }

      it { is_expected.to fail_a_contract }
    end

    context "when the user has paused notifications elsewhere too" do
      fab!(:own_pause) do
        Fabricate(
          :do_not_disturb_timing,
          user: current_user,
          starts_at: 1.minute.ago,
          ends_at: 1.day.from_now,
        )
      end

      before { start_pause(pause_key) }

      it "ends only the pause started for the meeting" do
        expect { result }.to change { current_user.do_not_disturb_timings.count }.by(-1)
        expect(current_user.do_not_disturb_timings).to contain_exactly(own_pause)
      end

      it "announces the pause that remains" do
        expect(messages.map(&:data)).to contain_exactly({ ends_at: own_pause.ends_at.httpdate })
      end
    end

    context "when everything's ok" do
      fab!(:shelved_notification) do
        ShelvedNotification.create!(notification: Fabricate(:notification, user: current_user))
      end

      before { start_pause(pause_key) }

      it { is_expected.to run_successfully }

      it "resumes notifications" do
        expect { result }.to change { current_user.do_not_disturb? }.from(true).to(false)
      end

      it "announces that notifications are resumed" do
        expect(messages.map(&:data)).to contain_exactly({ ends_at: nil })
      end

      it "delivers the notifications held during the pause" do
        expect { result }.to change { ShelvedNotification.exists?(shelved_notification.id) }.to(
          false,
        )
      end
    end
  end
end
