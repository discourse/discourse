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
        another_user = Fabricate(:user)
        message = Fabricate(:chat_message, chat_channel: chat_channel, user: another_user)
        message.trash!(another_user)

        sign_in(current_user)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{message.id}/restore.json"
        expect(response.status).to eq(403)
      end

      it "allows a user to restore their own messages" do
        message = Fabricate(:chat_message, chat_channel: chat_channel, user: current_user)
        message.trash!(current_user)

        sign_in(current_user)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{message.id}/restore.json"
        expect(response.status).to eq(200)
        expect(message.reload.deleted_at).to be_nil
      end

      it "allows admin to restore others' messages" do
        message = Fabricate(:chat_message, chat_channel: chat_channel, user: current_user)
        message.trash!(current_user)

        sign_in(admin)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{message.id}/restore.json"
        expect(response.status).to eq(200)
        expect(message.reload.deleted_at).to be_nil
      end

      it "does not allow message restore when channel is read_only" do
        message = Fabricate(:chat_message, chat_channel: chat_channel, user: current_user)
        message.trash!(current_user)

        sign_in(current_user)

        chat_channel.update!(status: :read_only)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{message.id}/restore.json"
        expect(response.status).to eq(403)
        expect(message.reload.deleted_at).not_to be_nil

        sign_in(admin)
        put "/chat/api/channels/#{chat_channel.id}/messages/#{message.id}/restore.json"
        expect(response.status).to eq(403)
      end

      it "only allows admin to restore when channel is closed" do
        message = Fabricate(:chat_message, chat_channel: chat_channel, user: current_user)
        message.trash!(current_user)

        sign_in(admin)

        chat_channel.update!(status: :read_only)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{message.id}/restore.json"
        expect(response.status).to eq(403)
        expect(message.reload.deleted_at).not_to be_nil

        chat_channel.update!(status: :closed)
        put "/chat/api/channels/#{chat_channel.id}/messages/#{message.id}/restore.json"
        expect(response.status).to eq(200)
        expect(message.reload.deleted_at).to be_nil
      end
    end

    fab!(:admin) { Fabricate(:admin) }
    fab!(:another_user) { Fabricate(:user) }

    describe "for category" do
      fab!(:category) { Fabricate(:category) }
      fab!(:chat_channel) { Fabricate(:category_channel, chatable: category) }

      it_behaves_like "chat_message_restoration"
    end

    describe "for dm channel" do
      fab!(:user_2) { Fabricate(:user) }
      fab!(:chat_channel) do
        Fabricate(:direct_message_channel, users: [current_user, another_user])
      end

      it_behaves_like "chat_message_restoration"
    end
  end

  describe "#create" do
    fab!(:user) { Fabricate(:user) }
    fab!(:category) { Fabricate(:category) }

    let(:message) { "This is a message" }

    describe "for category" do
      fab!(:chat_channel) { Fabricate(:category_channel, chatable: category) }

      context "when current user is silenced" do
        before do
          chat_channel.add(user)
          sign_in(user)
          UserSilencer.new(user).silence
        end

        it "raises invalid acces" do
          post "/chat/#{chat_channel.id}.json", params: { message: message }
          expect(response.status).to eq(403)
        end
      end

      it "errors for regular user when chat is staff-only" do
        sign_in(user)
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]

        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(403)
      end

      it "errors when the user isn't following the channel" do
        sign_in(user)

        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(403)
      end

      it "errors when the user is not staff and the channel is not open" do
        Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user)
        sign_in(user)

        chat_channel.update(status: :closed)
        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("chat.errors.channel_new_message_disallowed.closed"),
        )
      end

      it "errors when the user is staff and the channel is not open or closed" do
        Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: admin)
        sign_in(admin)

        chat_channel.update(status: :closed)
        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(200)

        chat_channel.update(status: :read_only)
        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("chat.errors.channel_new_message_disallowed.read_only"),
        )
      end

      context "when the regular user is following the channel" do
        fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel) }
        fab!(:membership) do
          Chat::UserChatChannelMembership.create(
            user: user,
            chat_channel: chat_channel,
            following: true,
            last_read_message_id: message_1.id,
          )
        end

        it "sends a message for regular user when staff-only is disabled and they are following channel" do
          sign_in(user)

          expect { post "/chat/#{chat_channel.id}.json", params: { message: message } }.to change {
            Chat::Message.count
          }.by(1)
          expect(response.status).to eq(200)
          expect(Chat::Message.last.message).to eq(message)
        end

        it "updates the last_read_message_id for the user who sent the message" do
          sign_in(user)
          post "/chat/#{chat_channel.id}.json", params: { message: message }
          expect(response.status).to eq(200)
          expect(membership.reload.last_read_message_id).to eq(Chat::Message.last.id)
        end

        it "publishes user tracking state using the new chat message as the last_read_message_id" do
          sign_in(user)
          messages =
            MessageBus.track_publish(
              Chat::Publisher.user_tracking_state_message_bus_channel(user.id),
            ) { post "/chat/#{chat_channel.id}.json", params: { message: message } }
          expect(response.status).to eq(200)
          expect(messages.first.data["last_read_message_id"]).to eq(Chat::Message.last.id)
        end

        context "when sending a message in a thread" do
          fab!(:thread) do
            Fabricate(:chat_thread, channel: chat_channel, original_message: message_1)
          end

          before { sign_in(user) }

          it "does not update the last_read_message_id for the user who sent the message" do
            post "/chat/#{chat_channel.id}.json", params: { message: message, thread_id: thread.id }
            expect(response.status).to eq(200)
            expect(membership.reload.last_read_message_id).to eq(message_1.id)
          end

          it "publishes user tracking state using the old membership last_read_message_id" do
            messages =
              MessageBus.track_publish(
                Chat::Publisher.user_tracking_state_message_bus_channel(user.id),
              ) do
                post "/chat/#{chat_channel.id}.json",
                     params: {
                       message: message,
                       thread_id: thread.id,
                     }
              end
            expect(response.status).to eq(200)
            expect(messages.first.data["last_read_message_id"]).to eq(message_1.id)
          end

          context "when thread is not part of the provided channel" do
            let!(:another_channel) { Fabricate(:category_channel) }

            before do
              Fabricate(:user_chat_channel_membership, chat_channel: another_channel, user: user)
            end

            it "returns an error" do
              post "/chat/#{another_channel.id}.json",
                   params: {
                     message: message,
                     thread_id: thread.id,
                   }
              expect(response).to have_http_status :unprocessable_entity
              expect(response.parsed_body["errors"]).to include(
                /thread is not part of the provided channel/i,
              )
            end
          end

          context "when provided thread does not match `reply_to_id`" do
            let!(:another_thread) { Fabricate(:chat_thread, channel: chat_channel) }

            it "returns an error" do
              post "/chat/#{chat_channel.id}.json",
                   params: {
                     message: message,
                     in_reply_to_id: message_1.id,
                     thread_id: another_thread.id,
                   }
              expect(response).to have_http_status :unprocessable_entity
              expect(response.parsed_body["errors"]).to include(/does not match parent message/)
            end
          end
        end
      end
    end

    describe "for direct message" do
      fab!(:user1) { Fabricate(:user) }
      fab!(:user2) { Fabricate(:user) }
      fab!(:chatable) { Fabricate(:direct_message, users: [user1, user2]) }
      fab!(:direct_message_channel) { Fabricate(:direct_message_channel, chatable: chatable) }

      it "forces users to follow the channel" do
        direct_message_channel.remove(user2)

        Chat::Publisher.expects(:publish_new_channel).once

        sign_in(user1)

        post "/chat/#{direct_message_channel.id}.json", params: { message: message }

        expect(Chat::UserChatChannelMembership.find_by(user_id: user2.id).following).to be true
      end

      it "doesn’t call publish new channel when already following" do
        Chat::Publisher.expects(:publish_new_channel).never

        sign_in(user1)

        post "/chat/#{direct_message_channel.id}.json", params: { message: message }
      end

      it "errors when the user is not part of the direct message channel" do
        Chat::DirectMessageUser.find_by(user: user1, direct_message: chatable).destroy!
        sign_in(user1)
        post "/chat/#{direct_message_channel.id}.json", params: { message: message }
        expect(response.status).to eq(403)

        Chat::UserChatChannelMembership.find_by(user_id: user2.id).update!(following: true)
        sign_in(user2)
        post "/chat/#{direct_message_channel.id}.json", params: { message: message }
        expect(response.status).to eq(200)
      end

      context "when current user is silenced" do
        before do
          sign_in(user1)
          UserSilencer.new(user1).silence
        end

        it "raises invalid acces" do
          post "/chat/#{direct_message_channel.id}.json", params: { message: message }
          expect(response.status).to eq(403)
        end
      end

      context "if any of the direct message users is ignoring the acting user" do
        before do
          IgnoredUser.create!(user: user2, ignored_user: user1, expiring_at: 1.day.from_now)
        end

        it "does not force them to follow the channel or send a publish_new_channel message" do
          direct_message_channel.remove(user2)

          Chat::Publisher.expects(:publish_new_channel).never

          sign_in(user1)
          post "/chat/#{direct_message_channel.id}.json", params: { message: message }

          expect(Chat::UserChatChannelMembership.find_by(user_id: user2.id).following).to be false
        end
      end
    end
  end
end
