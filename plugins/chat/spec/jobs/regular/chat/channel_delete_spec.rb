# frozen_string_literal: true

describe Jobs::Chat::ChannelDelete do
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

    10.times { Chat::MessageReaction.create(chat_message: messages.sample, user: users.sample) }

    10.times do
      upload = Fabricate(:upload, user: users.sample)
      message = messages.sample

      UploadReference.create(target: message, upload: upload)
    end

    Chat::Mention.create(
      user: user2,
      chat_message: messages.sample,
      notification: Fabricate(:notification),
    )

    @incoming_chat_webhook_id = Fabricate(:incoming_chat_webhook, chat_channel: chat_channel)
    Chat::WebhookEvent.create(
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

    Chat::Draft.create(chat_channel: chat_channel, user: users.sample, data: "wow some draft")

    Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user1)
    Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user2)
    Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user3)

    chat_channel.trash!
  end

  def counts
    {
      incoming_webhooks: Chat::IncomingWebhook.where(chat_channel_id: chat_channel.id).count,
      webhook_events:
        Chat::WebhookEvent.where(incoming_chat_webhook_id: @incoming_chat_webhook_id).count,
      drafts: Chat::Draft.where(chat_channel: chat_channel).count,
      channel_memberships: Chat::UserChatChannelMembership.where(chat_channel: chat_channel).count,
      revisions: Chat::MessageRevision.where(chat_message_id: @message_ids).count,
      mentions: Chat::Mention.where(chat_message_id: @message_ids).count,
      upload_references:
        UploadReference.where(target_id: @message_ids, target_type: Chat::Message.sti_name).count,
      messages: Chat::Message.where(id: @message_ids).count,
      reactions: Chat::MessageReaction.where(chat_message_id: @message_ids).count,
    }
  end

  it "deletes all of the messages and related records completely" do
    initial_counts = counts
    described_class.new.execute(chat_channel_id: chat_channel.id)
    new_counts = counts

    expect(new_counts[:incoming_webhooks]).to eq(initial_counts[:incoming_webhooks] - 1)
    expect(new_counts[:webhook_events]).to eq(initial_counts[:webhook_events] - 1)
    expect(new_counts[:drafts]).to eq(initial_counts[:drafts] - 1)
    expect(new_counts[:channel_memberships]).to eq(initial_counts[:channel_memberships] - 3)
    expect(new_counts[:revisions]).to eq(initial_counts[:revisions] - 1)
    expect(new_counts[:mentions]).to eq(initial_counts[:mentions] - 1)
    expect(new_counts[:upload_references]).to eq(initial_counts[:upload_references] - 10)
    expect(new_counts[:messages]).to eq(initial_counts[:messages] - 20)
    expect(new_counts[:reactions]).to eq(initial_counts[:reactions] - 10)
  end

  it "does not error if there are no messages in the channel" do
    other_channel = Fabricate(:chat_channel)
    expect { described_class.new.execute(chat_channel_id: other_channel.id) }.not_to raise_error
  end
end
