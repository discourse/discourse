# frozen_string_literal: true

RSpec.describe UserSuspender do
  fab!(:user) { Fabricate(:user, trust_level: 0) }
  fab!(:post) { Fabricate(:post, user: user) }
  fab!(:admin)

  describe "suspend" do
    subject(:suspend_user) { suspender.suspend }

    let(:suspender) do
      UserSuspender.new(
        user,
        suspended_till: 5.hours.from_now,
        reason: "because",
        by_user: admin,
        post_id: post.id,
        message: "you have been suspended",
      )
    end

    it "suspends the user and schedules automatic expiry" do
      freeze_time(Time.zone.now.round)

      suspend_user

      expect(user.reload).to be_suspended
      expect(user.suspended_till).to be_within_one_second_of(5.hours.from_now)
      expect(user.suspended_at).to be_within_one_second_of(Time.zone.now)

      job = Jobs::UserSuspensionExpired.jobs.last
      expect(job["at"]).to eq(user.suspended_till.to_f)
      expect(job["args"].first).to include(
        "user_id" => user.id,
        "suspended_at" => user.suspended_at.iso8601(UserSuspender::TIMESTAMP_PRECISION),
        "suspended_till" => user.suspended_till.iso8601(UserSuspender::TIMESTAMP_PRECISION),
      )
    end

    it "creates a staff action log" do
      expect do suspend_user end.to change {
        UserHistory.where(
          action: UserHistory.actions[:suspend_user],
          acting_user_id: admin.id,
          target_user_id: user.id,
        ).count
      }.from(0).to(1)
    end

    it "links the staff action log to the reviewable when passed via opts" do
      reviewable = Fabricate(:reviewable_flagged_post, target_created_by: user)
      suspender =
        UserSuspender.new(
          user,
          suspended_till: 5.hours.from_now,
          reason: "because",
          by_user: admin,
          post_id: post.id,
          message: "you have been suspended",
          reviewable_id: reviewable.id,
        )

      expect { suspender.suspend }.to change {
        UserHistory.where(
          action: UserHistory.actions[:suspend_user],
          reviewable_id: reviewable.id,
        ).count
      }.by(1)
    end

    it "logs the user out" do
      messages = MessageBus.track_publish("/logout/#{user.id}") { suspend_user }
      expect(messages.size).to eq(1)
      expect(messages[0].user_ids).to eq([user.id])
      expect(messages[0].data).to eq(user.id)
    end

    it "fires a user_suspended event" do
      freeze_time(Time.zone.now.round)
      events = DiscourseEvent.track_events(:user_suspended) { suspend_user }
      expect(events.size).to eq(1)

      params = events[0][:params].first
      expect(params[:user].id).to eq(user.id)
      expect(params[:by_user]).to eq(admin)
      expect(params[:reason]).to eq("because")
      expect(params[:message]).to eq("you have been suspended")
      expect(params[:suspended_till]).to be_within_one_second_of(5.hours.from_now)
      expect(params[:suspended_at]).to eq(Time.zone.now)
    end

    context "when a message is provided" do
      it "enqueues a critical user email job" do
        expect do suspend_user end.to change { Jobs::CriticalUserEmail.jobs.size }.from(0).to(1)

        job = Jobs::CriticalUserEmail.jobs.first
        expect(job["args"].first["user_id"]).to eq(user.id)
        expect(job["args"].first["user_history_id"]).to eq(suspender.user_history.id)
      end
    end

    context "when a message is not provided" do
      let(:suspender) do
        UserSuspender.new(
          user,
          suspended_till: 5.hours.from_now,
          reason: "because",
          by_user: admin,
          post_id: post.id,
          message: nil,
        )
      end

      it "doesn't enqueue a critical user email job" do
        expect do suspend_user end.not_to change { Jobs::CriticalUserEmail.jobs.size }.from(0)
      end
    end
  end

  describe ".unsuspend" do
    it "preserves the suspension on listener failure and identifies the moderator on retry" do
      user.update!(suspended_at: 1.hour.ago, suspended_till: 1.day.from_now)
      handler = proc { raise "Listener unavailable" }
      DiscourseEvent.on(:user_unsuspended, &handler)

      expect do described_class.unsuspend(user, by_user: admin) end.to raise_error(
        "Listener unavailable",
      )
      expect(user.reload).to be_suspended

      DiscourseEvent.off(:user_unsuspended, &handler)
      events =
        DiscourseEvent.track_events(:user_unsuspended) do
          described_class.unsuspend(user, by_user: admin)
        end

      expect(user.reload).to have_attributes(suspended_at: nil, suspended_till: nil)
      expect(events.map { |event| event[:params].first }).to contain_exactly(
        user: user,
        by_user: admin,
      )
    ensure
      DiscourseEvent.off(:user_unsuspended, &handler) if handler
    end
  end
end
