# frozen_string_literal: true

describe Chat::MessagesExporter do
  context "with different kinds of channels" do
    fab!(:public_channel) { Fabricate(:chat_channel) }
    fab!(:public_channel_message_1) { Fabricate(:chat_message, chat_channel: public_channel) }
    fab!(:public_channel_message_2) { Fabricate(:chat_message, chat_channel: public_channel) }
    # this message is deleted in the before block:
    fab!(:deleted_message) { Fabricate(:chat_message, chat_channel: public_channel) }

    fab!(:private_channel) { Fabricate(:private_category_channel, group: Fabricate(:group)) }
    fab!(:private_channel_message_1) { Fabricate(:chat_message, chat_channel: private_channel) }
    fab!(:private_channel_message_2) { Fabricate(:chat_message, chat_channel: private_channel) }

    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }
    fab!(:direct_message_1) do
      Fabricate(:chat_message, chat_channel: private_channel, user: user_1)
    end
    fab!(:direct_message_2) do
      Fabricate(:chat_message, chat_channel: private_channel, user: user_2)
    end

    before { deleted_message.trash! }

    it "exports messages" do
      exporter = Class.new.extend(Chat::MessagesExporter)

      result = []
      exporter.chat_message_export { |data_row| result << data_row }

      expect(result.length).to be(7)
      assert_exported_message(result[0], public_channel_message_1)
      assert_exported_message(result[1], public_channel_message_2)
      assert_exported_message(result[2], deleted_message)
      assert_exported_message(result[3], private_channel_message_1)
      assert_exported_message(result[4], private_channel_message_2)
      assert_exported_message(result[5], direct_message_1)
      assert_exported_message(result[6], direct_message_2)
    end
  end

  context "with messages from deleted channels" do
    fab!(:channel) { Fabricate(:chat_channel, deleted_at: Time.now) }
    fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }

    it "exports such messages" do
      exporter = Class.new.extend(Chat::MessagesExporter)

      result = []
      exporter.chat_message_export { |data_row| result << data_row }

      expect(result.length).to be(1)
      assert_exported_message(result[0], message)
    end
  end

  def assert_exported_message(data_row, message)
    Chat::Channel.unscoped do
      expect(data_row[0]).to eq(message.id)
      expect(data_row[1]).to eq(message.chat_channel.id)
      expect(data_row[2]).to eq(message.chat_channel.name)
      expect(data_row[3]).to eq(message.user.id)
      expect(data_row[4]).to eq(message.user.username)
      expect(data_row[5]).to eq(message.message)
      expect(data_row[6]).to eq(message.cooked)
      expect(data_row[7]).to eq_time(message.created_at)
      expect(data_row[8]).to eq_time(message.updated_at)
      expect(data_row[9]).to eq_time(message.deleted_at)
      expect(data_row[10]).to eq(message.in_reply_to_id)
      expect(data_row[11]).to eq(message.last_editor.id)
      expect(data_row[12]).to eq(message.last_editor.username)
    end
  end
end
