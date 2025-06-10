# frozen_string_literal: true

RSpec.describe "Webhook event handlers" do
  fab!(:user_badge)
  fab!(:web_hook) { Fabricate(:user_badge_web_hook) }
  fab!(:user)
  fab!(:badge)
  fab!(:post)

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

  describe "reviewable events" do
    fab!(:reviewable_webhook) do
      wh = Fabricate(:web_hook, categories: [post.topic.category])
      wh.web_hook_event_types = [WebHookEventType.find_by(name: "reviewable_created")]
      wh.save!
      wh
    end

    it "includes category_id in the job arguments" do
      reviewable = nil
      expect do
        reviewable =
          ReviewableFlaggedPost.needs_review!(target: post, created_by: Discourse.system_user)
      end.to change { Jobs::EmitWebHookEvent.jobs.size }.by(1)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
      expect(job_args["id"]).to eq(reviewable.id)
      expect(job_args["event_name"]).to eq("reviewable_created")
      expect(reviewable.category_id).to be_present
      expect(job_args["category_id"]).to eq(reviewable.category_id)
    end

    it "includes tag_ids in the job arguments" do
      tag = Fabricate(:tag)
      post.topic.tags << tag
      post.topic.save!

      reviewable_webhook.tag_ids = [tag.id]
      reviewable_webhook.save!

      reviewable = nil
      expect do
        reviewable =
          ReviewableFlaggedPost.needs_review!(target: post, created_by: Discourse.system_user)
      end.to change { Jobs::EmitWebHookEvent.jobs.size }.by(1)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
      expect(job_args["id"]).to eq(reviewable.id)
      expect(job_args["event_name"]).to eq("reviewable_created")
      expect(job_args["tag_ids"]).to eq([tag.id])
    end
  end
end
