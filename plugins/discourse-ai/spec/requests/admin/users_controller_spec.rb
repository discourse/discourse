# frozen_string_literal: true

RSpec.describe Admin::UsersController do
  fab!(:admin)
  fab!(:target_user, :user)
  fab!(:other_user, :user)

  before do
    enable_current_plugin
    sign_in(admin)
    Topic.any_instance.stubs(:topic_chat_channel).returns(nil)
  end

  describe "#delete_posts_batch" do
    it "keeps audit logs since the batch only soft-deletes posts" do
      first_post = Fabricate(:post, user: admin)
      target_post = Fabricate(:post, topic: first_post.topic, user: target_user)
      other_post = Fabricate(:post, topic: first_post.topic, user: other_user)
      target_log = Fabricate(:ai_api_audit_log, post_id: target_post.id)
      other_log = Fabricate(:ai_api_audit_log, post_id: other_post.id)

      put "/admin/users/#{target_user.id}/delete_posts_batch.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts_deleted"]).to eq(1)
      expect(target_post.reload.deleted_at).to be_present
      expect(AiApiAuditLog.where(id: target_log.id)).to be_exists
      expect(AiApiAuditLog.where(id: other_log.id)).to be_exists
    end
  end

  describe "#destroy" do
    it "deletes the target user's identity and content audit logs" do
      target_post = Fabricate(:post, user: target_user)
      topic = target_post.topic
      target_user_log = Fabricate(:ai_api_audit_log, user_id: target_user.id)
      target_post_log = Fabricate(:ai_api_audit_log, post_id: target_post.id)
      target_topic_log = Fabricate(:ai_api_audit_log, topic_id: topic.id)
      other_post = Fabricate(:post, user: other_user)
      other_topic = other_post.topic
      other_user_log = Fabricate(:ai_api_audit_log, user_id: other_user.id)
      other_post_log = Fabricate(:ai_api_audit_log, post_id: other_post.id)
      other_topic_log = Fabricate(:ai_api_audit_log, topic_id: other_topic.id)

      delete "/admin/users/#{target_user.id}.json", params: { delete_posts: true }

      expect(response.status).to eq(200)
      expect(
        AiApiAuditLog.where(id: [target_user_log.id, target_post_log.id, target_topic_log.id]),
      ).to be_empty
      expect(
        AiApiAuditLog.where(id: [other_user_log.id, other_post_log.id, other_topic_log.id]).pluck(
          :id,
        ),
      ).to contain_exactly(other_user_log.id, other_post_log.id, other_topic_log.id)
    end

    it "purges content logs through the delete-all-posts then delete-user flow" do
      target_post = Fabricate(:post, user: target_user)
      topic = target_post.topic
      target_user_log = Fabricate(:ai_api_audit_log, user_id: target_user.id)
      target_post_log = Fabricate(:ai_api_audit_log, post_id: target_post.id)
      target_topic_log = Fabricate(:ai_api_audit_log, topic_id: topic.id)

      put "/admin/users/#{target_user.id}/delete_posts_batch.json"

      # posts are only soft-deleted here, so the logs must survive until the
      # account itself is removed
      expect(target_post.reload.deleted_at).to be_present
      expect(
        AiApiAuditLog.where(id: [target_user_log.id, target_post_log.id, target_topic_log.id]),
      ).to be_exists

      delete "/admin/users/#{target_user.id}.json", params: { delete_posts: true }

      expect(response.status).to eq(200)
      expect(
        AiApiAuditLog.where(id: [target_user_log.id, target_post_log.id, target_topic_log.id]),
      ).to be_empty
    end

    it "leaves audit logs when deleting a user with posts is forbidden" do
      target_post = Fabricate(:post, user: target_user)
      topic = target_post.topic
      target_user_log = Fabricate(:ai_api_audit_log, user_id: target_user.id)
      target_post_log = Fabricate(:ai_api_audit_log, post_id: target_post.id)
      target_topic_log = Fabricate(:ai_api_audit_log, topic_id: topic.id)

      delete "/admin/users/#{target_user.id}.json"

      expect(response.status).to eq(403)
      expect(
        AiApiAuditLog.where(
          id: [target_user_log.id, target_post_log.id, target_topic_log.id],
        ).pluck(:id),
      ).to contain_exactly(target_user_log.id, target_post_log.id, target_topic_log.id)
    end
  end
end
