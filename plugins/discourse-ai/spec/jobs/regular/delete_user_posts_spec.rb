# frozen_string_literal: true

RSpec.describe Jobs::DeleteUserPosts do
  fab!(:admin)
  fab!(:target_user, :user)
  fab!(:other_user, :user)

  before do
    enable_current_plugin
    Topic.any_instance.stubs(:topic_chat_channel).returns(nil)
  end

  it "keeps audit logs for target posts since the batch only soft-deletes them" do
    first_post = Fabricate(:post, user: admin)
    target_posts = Fabricate.times(21, :post, topic: first_post.topic, user: target_user)
    target_logs = target_posts.map { |post| Fabricate(:ai_api_audit_log, post_id: post.id) }
    other_post = Fabricate(:post, user: other_user)
    other_topic = other_post.topic
    other_user_log = Fabricate(:ai_api_audit_log, user_id: other_user.id)
    other_post_log = Fabricate(:ai_api_audit_log, post_id: other_post.id)
    other_topic_log = Fabricate(:ai_api_audit_log, topic_id: other_topic.id)

    described_class.new.execute(user_id: target_user.id, acting_user_id: admin.id)

    expect(AiApiAuditLog.where(id: target_logs.map(&:id)).pluck(:id)).to contain_exactly(
      *target_logs.map(&:id),
    )
    expect(
      AiApiAuditLog.where(id: [other_user_log.id, other_post_log.id, other_topic_log.id]).pluck(
        :id,
      ),
    ).to contain_exactly(other_user_log.id, other_post_log.id, other_topic_log.id)
  end
end
