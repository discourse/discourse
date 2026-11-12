# frozen_string_literal: true

RSpec.describe Jobs::UserSuspensionExpired do
  fab!(:user)

  describe "#execute" do
    it "announces an expired suspension once and preserves its history" do
      freeze_time(Time.zone.now.round)
      started_at = 1.day.ago
      expiry = 1.hour.ago
      user.update!(suspended_at: started_at, suspended_till: expiry)
      args = {
        user_id: user.id,
        suspended_at: started_at.iso8601(UserSuspender::TIMESTAMP_PRECISION),
        suspended_till: expiry.iso8601(UserSuspender::TIMESTAMP_PRECISION),
      }

      events =
        DiscourseEvent.track_events(:user_unsuspended) do
          described_class.new.execute(args)
          described_class.new.execute(args)
          user
            .user_histories
            .where(action: UserHistory.actions[:unsuspend_user])
            .update_all(action: UserHistory.actions[:removed_unsuspend_user])
          described_class.new.execute(args)
        end

      expect(user.reload).to have_attributes(suspended_at: started_at, suspended_till: expiry)
      expect(events.map { |event| event[:params].first }).to contain_exactly(
        user: user,
        by_user: Discourse.system_user,
      )
    end

    it "ignores replaced suspensions and early jobs" do
      freeze_time(Time.zone.now.round)
      expiry = 1.day.from_now
      user.update!(suspended_at: 1.day.ago, suspended_till: 1.hour.ago)

      events =
        DiscourseEvent.track_events(:user_unsuspended) do
          described_class.new.execute(
            user_id: user.id,
            suspended_at: user.suspended_at.iso8601(UserSuspender::TIMESTAMP_PRECISION),
            suspended_till: 2.hours.ago.iso8601(UserSuspender::TIMESTAMP_PRECISION),
          )
          user.update!(suspended_till: expiry)
          described_class.new.execute(
            user_id: user.id,
            suspended_at: user.suspended_at.iso8601(UserSuspender::TIMESTAMP_PRECISION),
            suspended_till: expiry.iso8601(UserSuspender::TIMESTAMP_PRECISION),
          )
        end

      expect(user.reload.suspended_till).to eq(expiry)
      expect(events).to be_empty
    end

    it "distinguishes separate suspensions with the same expiry" do
      freeze_time(Time.zone.now.round)
      expiry = 1.hour.ago
      user.update!(suspended_at: 2.days.ago, suspended_till: expiry)
      args = {
        user_id: user.id,
        suspended_at: user.suspended_at.iso8601(UserSuspender::TIMESTAMP_PRECISION),
        suspended_till: expiry.iso8601(UserSuspender::TIMESTAMP_PRECISION),
      }

      events =
        DiscourseEvent.track_events(:user_unsuspended) do
          described_class.new.execute(args)
          user.update!(suspended_at: 1.day.ago)
          described_class.new.execute(args)
          described_class.new.execute(
            args.merge(suspended_at: user.suspended_at.iso8601(UserSuspender::TIMESTAMP_PRECISION)),
          )
        end

      expect(events.size).to eq(2)
      expect(user.reload).to have_attributes(suspended_at: 1.day.ago, suspended_till: expiry)
    end

    it "retries notification when an event listener fails" do
      user.update!(suspended_at: 1.day.ago, suspended_till: 1.hour.ago)
      args = {
        user_id: user.id,
        suspended_at: user.suspended_at.iso8601(UserSuspender::TIMESTAMP_PRECISION),
        suspended_till: user.suspended_till.iso8601(UserSuspender::TIMESTAMP_PRECISION),
      }
      handler = proc { raise "Listener unavailable" }
      DiscourseEvent.on(:user_unsuspended, &handler)

      expect { described_class.new.execute(args) }.to raise_error("Listener unavailable")
      DiscourseEvent.off(:user_unsuspended, &handler)
      events = DiscourseEvent.track_events(:user_unsuspended) { described_class.new.execute(args) }

      expect(events.size).to eq(1)
    ensure
      DiscourseEvent.off(:user_unsuspended, &handler) if handler
    end
  end
end
