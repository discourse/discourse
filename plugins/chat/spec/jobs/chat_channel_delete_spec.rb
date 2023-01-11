# frozen_string_literal: true

describe Jobs::ChatChannelDelete do
  fab!(:chat_channel) { Fabricate(:chat_channel) }
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }
  let(:users) { [user1, user2, user3] }

  before do
    messages = []
    20.times do
      messages << Fabricate(:chat_message, chat_channel: chat_channel, user: users.sample)
    end
    @message_ids = messages.map(&:id)

    10.times { ChatMessageReaction.create(chat_message: messages.sample, user: users.sample) }

    10.times do
      ChatUpload.create(
        upload: Fabricate(:upload, user: users.sample),
        chat_message: messages.sample,
      )
    end

    ChatMention.create(
      user: user2,
      chat_message: messages.sample,
      notification: Fabricate(:notification),
    )

    @incoming_chat_webhook_id = Fabricate(:incoming_chat_webhook, chat_channel: chat_channel)
    ChatWebhookEvent.create(
      incoming_chat_webhook: @incoming_chat_webhook_id,
      chat_message: messages.sample,
    )

    revision_message = messages.sample
    Fabricate(
      :chat_message_revision,
      chat_message: revision_message,
      old_message: "some old message",
      new_message: revision_message.message,
    )

    ChatDraft.create(chat_channel: chat_channel, user: users.sample, data: "wow some draft")

    Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user1)
    Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user2)
    Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user3)

    chat_channel.trash!
  end

  it "deletes all of the messages and related records completely" do
    expect { described_class.new.execute(chat_channel_id: chat_channel.id) }.to change {
      IncomingChatWebhook.where(chat_channel_id: chat_channel.id).count
    }.by(-1).and change {
            ChatWebhookEvent.where(incoming_chat_webhook_id: @incoming_chat_webhook_id).count
          }.by(-1).and change { ChatDraft.where(chat_channel: chat_channel).count }.by(
                  -1,
                ).and change {
                        UserChatChannelMembership.where(chat_channel: chat_channel).count
                      }.by(-3).and change {
                              ChatMessageRevision.where(chat_message_id: @message_ids).count
                            }.by(-1).and change {
                                    ChatMention.where(chat_message_id: @message_ids).count
                                  }.by(-1).and change {
                                          ChatUpload.where(chat_message_id: @message_ids).count
                                        }.by(-10).and change {
                                                ChatMessage.where(id: @message_ids).count
                                              }.by(-20).and change {
                                                      ChatMessageReaction.where(
                                                        chat_message_id: @message_ids,
                                                      ).count
                                                    }.by(-10)
  end
end
