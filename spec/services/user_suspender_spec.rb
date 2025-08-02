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

    it "suspends the user correctly" do
      freeze_time
      suspend_user
      expect(user.reload).to be_suspended
      expect(user.suspended_till).to be_within_one_second_of(5.hours.from_now)
      expect(user.suspended_at).to be_within_one_second_of(Time.zone.now)
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

    it "logs the user out" do
      messages = MessageBus.track_publish("/logout/#{user.id}") { suspend_user }
      expect(messages.size).to eq(1)
      expect(messages[0].user_ids).to eq([user.id])
      expect(messages[0].data).to eq(user.id)
    end

    it "fires a user_suspended event" do
      freeze_time
      events = DiscourseEvent.track_events(:user_suspended) { suspend_user }
      expect(events.size).to eq(1)

      params = events[0][:params].first
      expect(params[:user].id).to eq(user.id)
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
end
