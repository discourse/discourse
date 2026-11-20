# frozen_string_literal: true

RSpec.describe UserNotificationPause do
  subject(:pause) { described_class.new(user:) }

  fab!(:user)

  let(:source) { "meeting" }
  let(:key) { SecureRandom.uuid }

  before { freeze_time }

  describe "#start" do
    it "creates an ordinary timed pause" do
      timing = pause.start(ends_at: 1.hour.from_now)

      expect(timing).to be_persisted
      expect(timing.starts_at).to eq_time(Time.zone.now)
      expect(user.do_not_disturb_until).to eq_time(1.hour.from_now)
    end

    it "reuses the timing for repeated keyed starts" do
      timing = pause.start(ends_at: 1.hour.from_now, source:, key:)
      repeated_timing = pause.start(ends_at: 2.hours.from_now, source:, key:)

      expect(repeated_timing).to eq(timing)
      expect(user.do_not_disturb_timings).to contain_exactly(timing)
      expect(timing.reload.ends_at).to eq_time(1.hour.from_now)
    end

    it "rejects a start after the key was ended" do
      pause.end(source:, key:)

      expect(pause.start(ends_at: 1.hour.from_now, source:, key:)).to be_nil
      expect(user.do_not_disturb_timings.reload).to be_empty
    end

    it "returns an invalid timing without announcing a pause" do
      messages =
        MessageBus.track_publish("/do-not-disturb/#{user.id}") do
          timing = pause.start(ends_at: 1.hour.ago, source:, key:)
          expect(timing).not_to be_persisted
          expect(timing.errors[:ends_at]).to be_present
        end

      expect(messages).to be_empty
      expect(user.do_not_disturb_timings.reload).to be_empty
    end

    it "announces the effective end time when a longer pause exists" do
      Fabricate(:do_not_disturb_timing, user:, ends_at: 1.day.from_now)

      messages =
        MessageBus.track_publish("/do-not-disturb/#{user.id}") do
          pause.start(ends_at: 1.hour.from_now, source:, key:)
        end

      expect(messages.map(&:data)).to contain_exactly({ ends_at: 1.day.from_now.httpdate })
    end

    it "requires source and key together" do
      expect { pause.start(ends_at: 1.hour.from_now, source:) }.to raise_error(ArgumentError)
      expect { pause.start(ends_at: 1.hour.from_now, key:) }.to raise_error(ArgumentError)
      expect(user.do_not_disturb_timings.reload).to be_empty
    end
  end

  describe "#end" do
    it "preserves manual and scheduled pauses and their shelved notifications" do
      manual_timing = Fabricate(:do_not_disturb_timing, user:, ends_at: 1.day.from_now)
      scheduled_timing =
        Fabricate(:do_not_disturb_timing, user:, scheduled: true, ends_at: 2.days.from_now)
      shelved_notification =
        ShelvedNotification.create!(notification: Fabricate(:notification, user:))
      pause.start(ends_at: 1.hour.from_now, source:, key:)

      messages = MessageBus.track_publish("/do-not-disturb/#{user.id}") { pause.end(source:, key:) }

      expect(user.do_not_disturb_timings).to contain_exactly(manual_timing, scheduled_timing)
      expect(shelved_notification.reload).to be_persisted
      expect(messages.map(&:data)).to contain_exactly({ ends_at: 2.days.from_now.httpdate })
    end

    it "isolates pauses by user, source, and key" do
      other_user = Fabricate(:user)
      other_user_pause = described_class.new(user: other_user)
      other_user_timing = other_user_pause.start(ends_at: 1.hour.from_now, source:, key:)
      other_source_timing = pause.start(ends_at: 1.hour.from_now, source: "call", key:)
      other_key_timing = pause.start(ends_at: 1.hour.from_now, source:, key: SecureRandom.uuid)
      pause.start(ends_at: 1.hour.from_now, source:, key:)

      pause.end(source:, key:)

      expect(user.do_not_disturb_timings).to contain_exactly(other_source_timing, other_key_timing)
      expect(other_user.do_not_disturb_timings).to contain_exactly(other_user_timing)
    end

    it "resumes and delivers shelved notifications when the last pause ends" do
      pause.start(ends_at: 1.hour.from_now, source:, key:)
      shelved_notification =
        ShelvedNotification.create!(notification: Fabricate(:notification, user:))

      messages = MessageBus.track_publish("/do-not-disturb/#{user.id}") { pause.end(source:, key:) }

      expect(user).not_to be_do_not_disturb
      expect(ShelvedNotification.exists?(shelved_notification.id)).to eq(false)
      expect(messages.map(&:data)).to contain_exactly({ ends_at: nil })
    end

    it "allows repeated ends and prevents a later start" do
      pause.start(ends_at: 1.hour.from_now, source:, key:)
      pause.end(source:, key:)
      pause.end(source:, key:)

      expect(pause.start(ends_at: 1.hour.from_now, source:, key:)).to be_nil
      expect(user.do_not_disturb_timings.reload).to be_empty
    end

    it "allows a fresh key after cancellation" do
      pause.end(source:, key:)
      timing = pause.start(ends_at: 1.hour.from_now, source:, key: SecureRandom.uuid)

      expect(user.do_not_disturb_timings).to contain_exactly(timing)
    end
  end

  describe "#end_all" do
    it "ends all active pauses, preserves future schedules, and delivers shelved notifications" do
      pause.start(ends_at: 1.hour.from_now, source:, key:)
      pause.start(ends_at: 2.hours.from_now)
      Fabricate(:do_not_disturb_timing, user:, scheduled: true, ends_at: 1.day.from_now)
      future_timing =
        Fabricate(
          :do_not_disturb_timing,
          user:,
          scheduled: true,
          starts_at: 2.days.from_now,
          ends_at: 3.days.from_now,
        )
      shelved_notification =
        ShelvedNotification.create!(notification: Fabricate(:notification, user:))

      messages = MessageBus.track_publish("/do-not-disturb/#{user.id}") { pause.end_all }

      expect(user.do_not_disturb_timings).to contain_exactly(future_timing)
      expect(ShelvedNotification.exists?(shelved_notification.id)).to eq(false)
      expect(messages.map(&:data)).to contain_exactly({ ends_at: nil })
      expect(pause.start(ends_at: 1.hour.from_now, source:, key:)).to be_nil
    end
  end
end
