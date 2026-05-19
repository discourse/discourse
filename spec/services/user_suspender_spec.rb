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

    it "suspends and logs out anonymous shadow accounts" do
      freeze_time
      SiteSetting.allow_anonymous_mode = true
      SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
      shadow_user = AnonymousShadowCreator.get(user)
      UserAuthToken.generate!(user_id: shadow_user.id)

      messages = MessageBus.track_publish("/logout/#{shadow_user.id}") { suspend_user }

      expect(shadow_user.reload[:suspended_till]).to be_within_one_second_of(5.hours.from_now)
      expect(shadow_user[:suspended_at]).to be_within_one_second_of(Time.zone.now)
      expect(shadow_user.user_auth_tokens).to be_empty
      expect(shadow_user.anonymous_user_master.reload.active).to eq(false)
      expect(messages.size).to eq(1)
      expect(messages[0].user_ids).to eq([shadow_user.id])
      expect(messages[0].data).to eq(shadow_user.id)
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
