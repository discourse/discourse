# frozen_string_literal: true

RSpec.describe "Webhook event handlers" do
  fab!(:user_badge) { Fabricate(:user_badge) }
  fab!(:web_hook) { Fabricate(:user_badge_web_hook) }
  fab!(:user) { Fabricate(:user) }
  fab!(:badge) { Fabricate(:badge) }
  fab!(:post) { Fabricate(:post) }

  describe "user_badge events" do
    it "enqueues user_badge_granted webhook event" do
      expect do
        BadgeGranter.grant(badge, user, granted_by: Discourse.system_user, post_id: post.id)
      end.to change { Jobs::EmitWebHookEvent.jobs.size }.by(1)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
      expect(job_args["id"]).to eq(user.user_badges.last.id)
      expect(job_args["event_name"]).to eq("user_badge_granted")
    end

    it "enqueues user_badge_revoked webhook event" do
      expect { BadgeGranter.revoke(user_badge) }.to change { Jobs::EmitWebHookEvent.jobs.size }.by(
        1,
      )

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
      expect(job_args["id"]).to eq(user_badge.id)
      expect(job_args["event_name"]).to eq("user_badge_revoked")
    end
  end
end
