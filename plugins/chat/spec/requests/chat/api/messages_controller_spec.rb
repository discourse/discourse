# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelMessagesController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#delete" do
    RSpec.shared_examples "chat_message_deletion" do
      it "doesn't allow a user to delete another user's message" do
        sign_in(other_user)

        delete "/chat/api/channels/#{message.chat_channel_id}/messages/#{message.id}.json"
        expect(response.status).to eq(403)
      end

      it "doesn't allow a silenced user to delete their message" do
        sign_in(other_user)
        UserSilencer.new(other_user).silence

        delete "/chat/api/channels/#{message.chat_channel_id}/messages/#{other_user_message.id}.json"
        expect(response.status).to eq(403)
      end

      it "allows admin to delete others' messages" do
        sign_in(admin)

        expect {
          delete "/chat/api/channels/#{message.chat_channel_id}/messages/#{message.id}.json"
        }.to change { Chat::Message.count }.by(-1)
        expect(response.status).to eq(200)
      end

      it "does not allow message delete when chat channel is read_only" do
        sign_in(message.user)

        chat_channel.update!(status: :read_only)
        expect {
          delete "/chat/api/channels/#{message.chat_channel_id}/messages/#{message.id}.json"
        }.not_to change { Chat::Message.count }
        expect(response.status).to eq(403)

        sign_in(admin)
        delete "/chat/api/channels/#{message.chat_channel_id}/messages/#{message.id}.json"
        expect(response.status).to eq(403)
      end

      it "only allows admin to delete when chat channel is closed" do
        sign_in(admin)

        chat_channel.update!(status: :read_only)
        expect {
          delete "/chat/api/channels/#{message.chat_channel_id}/messages/#{message.id}.json"
        }.not_to change { Chat::Message.count }
        expect(response.status).to eq(403)

        chat_channel.update!(status: :closed)
        expect {
          delete "/chat/api/channels/#{message.chat_channel_id}/messages/#{message.id}.json"
        }.to change { Chat::Message.count }.by(-1)
        expect(response.status).to eq(200)
      end
    end

    describe "for category" do
      fab!(:user_2) { Fabricate(:user) }
      fab!(:chat_channel) { Fabricate(:chat_channel) }
      fab!(:message) { Fabricate(:chat_message, chat_channel: chat_channel, user: current_user) }
      fab!(:user_2_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: user_2) }

      it_behaves_like "chat_message_deletion" do
        let(:other_user) { user_2 }
        let(:other_user_message) { user_2_message }
      end

      it "allows users to delete their own messages" do
        sign_in(current_user)
        expect {
          delete "/chat/api/channels/#{message.chat_channel_id}/messages/#{message.id}.json"
        }.to change { Chat::Message.count }.by(-1)
        expect(response.status).to eq(200)
      end
    end

    describe "for dm channel" do
      fab!(:user_2) { Fabricate(:user) }
      fab!(:chat_channel) { Fabricate(:direct_message_channel, users: [current_user, user_2]) }
      fab!(:message) { Fabricate(:chat_message, chat_channel: chat_channel, user: current_user) }
      fab!(:user_2_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: user_2) }

      it_behaves_like "chat_message_deletion" do
        let(:other_user) { user_2 }
        let(:other_user_message) { user_2_message }
      end

      it "allows users to delete their own messages" do
        sign_in(current_user)
        expect {
          delete "/chat/api/channels/#{message.chat_channel_id}/messages/#{message.id}.json"
        }.to change { Chat::Message.count }.by(-1)
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#restore" do
    RSpec.shared_examples "chat_message_restoration" do
      it "doesn't allow a user to restore another user's message" do
        sign_in(other_user)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{deleted_message.id}/restore.json"
        expect(response.status).to eq(403)
      end

      it "allows a user to restore their own posts" do
        sign_in(current_user)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{deleted_message.id}/restore.json"
        expect(response.status).to eq(200)
        expect(deleted_message.reload.deleted_at).to be_nil
      end

      it "allows admin to restore others' posts" do
        sign_in(admin)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{deleted_message.id}/restore.json"
        expect(response.status).to eq(200)
        expect(deleted_message.reload.deleted_at).to be_nil
      end

      it "does not allow message restore when chat channel is read_only" do
        sign_in(current_user)

        chat_channel.update!(status: :read_only)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{deleted_message.id}/restore.json"
        expect(response.status).to eq(403)
        expect(deleted_message.reload.deleted_at).not_to be_nil

        sign_in(admin)
        put "/chat/api/channels/#{chat_channel.id}/messages/#{deleted_message.id}/restore.json"
        expect(response.status).to eq(403)
      end

      it "only allows admin to restore when chat channel is closed" do
        sign_in(admin)

        chat_channel.update!(status: :read_only)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{deleted_message.id}/restore.json"
        expect(response.status).to eq(403)
        expect(deleted_message.reload.deleted_at).not_to be_nil

        chat_channel.update!(status: :closed)
        put "/chat/api/channels/#{chat_channel.id}/messages/#{deleted_message.id}/restore.json"
        expect(response.status).to eq(200)
        expect(deleted_message.reload.deleted_at).to be_nil
      end
    end

    fab!(:admin) { Fabricate(:admin) }
    fab!(:second_user) { Fabricate(:user) }

    before do
      message =
        Chat::Message.create(
          user: current_user,
          message: "this is a message",
          chat_channel: chat_channel,
        )
      message.trash!
    end

    let(:deleted_message) do
      Chat::Message.unscoped.where(user: current_user, chat_channel: chat_channel).last
    end

    describe "for category" do
      fab!(:category) { Fabricate(:category) }
      fab!(:chat_channel) { Fabricate(:category_channel, chatable: category) }

      it_behaves_like "chat_message_restoration" do
        let(:other_user) { second_user }
      end
    end

    describe "for dm channel" do
      fab!(:user_2) { Fabricate(:user) }
      fab!(:chat_channel) { Fabricate(:direct_message_channel, users: [current_user, user_2]) }

      it_behaves_like "chat_message_restoration" do
        let(:other_user) { user_2 }
      end
    end
  end
end
