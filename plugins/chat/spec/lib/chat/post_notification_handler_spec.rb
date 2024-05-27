# frozen_string_literal: true

describe Chat::PostNotificationHandler do
  subject(:handler) { described_class.new(post, notified_users) }

  let(:acting_user) { Fabricate(:user) }
  let(:post) { Fabricate(:post) }
  let(:notified_users) { [] }

  fab!(:channel) { Fabricate(:category_channel) }
  fab!(:message1) do
    Fabricate(:chat_message, chat_channel: channel, message: "hey this is the first message :)")
  end
  fab!(:message2) do
    Fabricate(
      :chat_message,
      chat_channel: channel,
      message: "our true enemy. has yet. to reveal himself.",
    )
  end

  before { Notification.destroy_all }

  def expect_no_notification
    return_val = nil
    expect { return_val = handler.handle }.not_to change { Notification.count }
    expect(return_val).to eq(false)
  end

  def update_post_with_chat_quote(messages)
    quote_markdown =
      Chat::TranscriptService.new(channel, acting_user, messages_or_ids: messages).generate_markdown
    post.update!(raw: post.raw + "\n\n" + quote_markdown)
  end

  it "does nothing if the post is a whisper" do
    post.update(post_type: Post.types[:whisper])
    expect_no_notification
  end

  it "does nothing if the topic is deleted" do
    post.topic.destroy && post.reload
    expect_no_notification
  end

  it "does nothing if the topic is a private message" do
    post.update(topic: Fabricate(:private_message_topic))
    expect_no_notification
  end

  it "sends notifications to all of the quoted users" do
    update_post_with_chat_quote([message1, message2])
    handler.handle
    expect(
      Notification.where(
        user: message1.user,
        notification_type: Notification.types[:chat_quoted],
      ).count,
    ).to eq(1)
    expect(
      Notification.where(
        user: message2.user,
        notification_type: Notification.types[:chat_quoted],
      ).count,
    ).to eq(1)
  end

  it "does not send the same chat_quoted notification twice to the same post and user" do
    update_post_with_chat_quote([message1, message2])
    handler.handle
    handler.handle
    expect(
      Notification.where(
        user: message1.user,
        notification_type: Notification.types[:chat_quoted],
      ).count,
    ).to eq(1)
  end

  it "does not send a notification if the user has got a reply notification to the quoted user for the same post" do
    update_post_with_chat_quote([message1, message2])
    Fabricate(
      :notification,
      notification_type: Notification.types[:replied],
      post_number: post.post_number,
      topic: post.topic,
      user: message1.user,
    )
    handler.handle
    expect(
      Notification.where(
        user: message1.user,
        notification_type: Notification.types[:chat_quoted],
      ).count,
    ).to eq(0)
  end

  context "when some users have already been notified for the post" do
    let(:notified_users) { [message1.user] }

    it "does not send notifications to those users" do
      update_post_with_chat_quote([message1, message2])
      handler.handle
      expect(
        Notification.where(
          user: message1.user,
          notification_type: Notification.types[:chat_quoted],
        ).count,
      ).to eq(0)
      expect(
        Notification.where(
          user: message2.user,
          notification_type: Notification.types[:chat_quoted],
        ).count,
      ).to eq(1)
    end
  end
end
