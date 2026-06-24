# frozen_string_literal: true

RSpec.describe DiscourseAi::AiApiAuditLogCleaner do
  fab!(:admin)
  fab!(:target_user, :user)
  fab!(:other_user, :user)

  before do
    enable_current_plugin
    Topic.any_instance.stubs(:topic_chat_channel).returns(nil)
  end

  it "removes only matching post logs when a post is permanently destroyed" do
    first_post = Fabricate(:post, user: admin)
    target_post = Fabricate(:post, topic: first_post.topic, user: target_user)
    other_post = Fabricate(:post, topic: first_post.topic, user: other_user)
    target_log = Fabricate(:ai_api_audit_log, post_id: target_post.id)
    other_log = Fabricate(:ai_api_audit_log, post_id: other_post.id)

    PostDestroyer.new(admin, target_post, force_destroy: true).destroy

    expect(AiApiAuditLog.where(id: target_log.id)).to be_empty
    expect(AiApiAuditLog.where(id: other_log.id)).to be_exists
  end

  it "keeps post logs when a post is only soft-deleted (recoverable)" do
    first_post = Fabricate(:post, user: admin)
    target_post = Fabricate(:post, topic: first_post.topic, user: target_user)
    target_log = Fabricate(:ai_api_audit_log, post_id: target_post.id)

    PostDestroyer.new(admin, target_post).destroy

    expect(target_post.reload.deleted_at).to be_present
    expect(AiApiAuditLog.where(id: target_log.id)).to be_exists
  end

  it "removes only matching topic logs when a topic is permanently destroyed" do
    target_post = Fabricate(:post, user: target_user)
    topic = target_post.topic
    other_post = Fabricate(:post, user: other_user)
    other_topic = other_post.topic
    target_log = Fabricate(:ai_api_audit_log, topic_id: topic.id)
    other_log = Fabricate(:ai_api_audit_log, topic_id: other_topic.id)

    PostDestroyer.new(admin, target_post, force_destroy: true).destroy

    expect(AiApiAuditLog.where(id: target_log.id)).to be_empty
    expect(AiApiAuditLog.where(id: other_log.id)).to be_exists
  end

  it "keeps topic logs when a topic is only soft-deleted (recoverable)" do
    target_post = Fabricate(:post, user: target_user)
    topic = target_post.topic
    target_log = Fabricate(:ai_api_audit_log, topic_id: topic.id)

    PostDestroyer.new(admin, target_post).destroy

    expect(topic.reload.deleted_at).to be_present
    expect(AiApiAuditLog.where(id: target_log.id)).to be_exists
  end

  it "removes only matching user logs when a user is destroyed" do
    target_log = Fabricate(:ai_api_audit_log, user_id: target_user.id)
    other_log = Fabricate(:ai_api_audit_log, user_id: other_user.id)

    UserDestroyer.new(admin).destroy(target_user)

    expect(AiApiAuditLog.where(id: target_log.id)).to be_empty
    expect(AiApiAuditLog.where(id: other_log.id)).to be_exists
  end

  describe ".delete_for_user_content" do
    it "removes logs for the user's posts and topics, including soft-deleted ones" do
      live_post = Fabricate(:post, user: target_user)
      live_topic = live_post.topic
      trashed_post = Fabricate(:post, user: target_user)
      trashed_topic = trashed_post.topic
      PostDestroyer.new(admin, trashed_post).destroy

      target_post_log = Fabricate(:ai_api_audit_log, post_id: live_post.id)
      target_topic_log = Fabricate(:ai_api_audit_log, topic_id: live_topic.id)
      trashed_post_log = Fabricate(:ai_api_audit_log, post_id: trashed_post.id)
      trashed_topic_log = Fabricate(:ai_api_audit_log, topic_id: trashed_topic.id)
      other_post = Fabricate(:post, user: other_user)
      other_post_log = Fabricate(:ai_api_audit_log, post_id: other_post.id)
      target_user_log = Fabricate(:ai_api_audit_log, user_id: target_user.id)

      described_class.delete_for_user_content(target_user)

      expect(
        AiApiAuditLog.where(
          id: [target_post_log.id, target_topic_log.id, trashed_post_log.id, trashed_topic_log.id],
        ),
      ).to be_empty
      # only content logs are touched here; user-id logs go through delete_for_user
      expect(
        AiApiAuditLog.where(id: [other_post_log.id, target_user_log.id]).pluck(:id),
      ).to contain_exactly(other_post_log.id, target_user_log.id)
    end
  end
end
