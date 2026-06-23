# frozen_string_literal: true

RSpec.describe DiscourseAi::AiApiAuditLogCleaner do
  fab!(:admin)
  fab!(:target_user, :user)
  fab!(:other_user, :user)

  before do
    enable_current_plugin
    Topic.any_instance.stubs(:topic_chat_channel).returns(nil)
  end

  it "removes only matching post logs when a post is deleted" do
    first_post = Fabricate(:post, user: admin)
    target_post = Fabricate(:post, topic: first_post.topic, user: target_user)
    other_post = Fabricate(:post, topic: first_post.topic, user: other_user)
    target_log = Fabricate(:ai_api_audit_log, post_id: target_post.id)
    other_log = Fabricate(:ai_api_audit_log, post_id: other_post.id)

    PostDestroyer.new(admin, target_post).destroy

    expect(AiApiAuditLog.where(id: target_log.id)).to be_empty
    expect(AiApiAuditLog.where(id: other_log.id)).to be_exists
  end

  it "removes only matching topic logs when a topic is deleted" do
    target_post = Fabricate(:post, user: target_user)
    topic = target_post.topic
    other_post = Fabricate(:post, user: other_user)
    other_topic = other_post.topic
    target_log = Fabricate(:ai_api_audit_log, topic_id: topic.id)
    other_log = Fabricate(:ai_api_audit_log, topic_id: other_topic.id)

    PostDestroyer.new(admin, target_post).destroy

    expect(AiApiAuditLog.where(id: target_log.id)).to be_empty
    expect(AiApiAuditLog.where(id: other_log.id)).to be_exists
  end

  it "removes only matching user logs when a user is destroyed" do
    target_log = Fabricate(:ai_api_audit_log, user_id: target_user.id)
    other_log = Fabricate(:ai_api_audit_log, user_id: other_user.id)

    UserDestroyer.new(admin).destroy(target_user)

    expect(AiApiAuditLog.where(id: target_log.id)).to be_empty
    expect(AiApiAuditLog.where(id: other_log.id)).to be_exists
  end
end
