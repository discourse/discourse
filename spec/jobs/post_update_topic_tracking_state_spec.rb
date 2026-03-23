# frozen_string_literal: true

RSpec.describe Jobs::PostUpdateTopicTrackingState do
  subject(:job) { described_class.new }

  fab!(:post)

  it "should publish messages" do
    messages = MessageBus.track_publish { job.execute({ post_id: post.id }) }
    expect(messages.size).not_to eq(0)
  end

  it "should not publish messages for deleted topics" do
    post.topic.trash!
    messages = MessageBus.track_publish { job.execute({ post_id: post.id }) }
    expect(messages.size).to eq(0)
  end

  it "should not update topic groups for small_action posts in private messages" do
    user = Fabricate(:user, refresh_auto_groups: true)
    recipient = Fabricate(:user)
    pm =
      create_post(
        user: user,
        target_usernames: [recipient.username],
        archetype: Archetype.private_message,
      )

    small_action =
      Fabricate(
        :post,
        topic: pm.topic,
        user: Discourse.system_user,
        post_type: Post.types[:small_action],
        action_code: "visible.disabled",
      )

    TopicGroup.expects(:new_message_update).never
    job.execute({ post_id: small_action.id })
  end
end
