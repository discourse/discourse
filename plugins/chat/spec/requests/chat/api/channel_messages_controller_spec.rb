# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelMessagesController do
  fab!(:current_user, :user)
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel.add(current_user)
    sign_in(current_user)
  end

  describe "#index" do
    describe "success" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }
      fab!(:message_2, :chat_message)

      it "works" do
        get "/chat/api/channels/#{channel.id}/messages"

        expect(response.status).to eq(200)
        expect(response.parsed_body["messages"].map { |m| m["id"] }).to contain_exactly(
          message_1.id,
        )
      end

      context "as anonymous user" do
        before do
          delete "/session/#{current_user.username}.json"
          SiteSetting.chat_allowed_groups =
            "#{Group::AUTO_GROUPS[:everyone]}|#{Group::AUTO_GROUPS[:anonymous_users]}"
        end

        it "returns messages for a public category channel" do
          thread = Fabricate(:chat_thread, channel:, original_message: message_1)
          thread_reply = Fabricate(:chat_message, chat_channel: channel, thread:)

          get "/chat/api/channels/#{channel.id}/messages"

          expect(response.status).to eq(200)
          expect(response.parsed_body["messages"].map { |message| message["id"] }).to eq(
            [message_1.id, thread_reply.id],
          )
        end

        it "returns an error for a direct message channel" do
          direct_message_channel =
            Fabricate(:direct_message_channel, group: true, users: Fabricate.times(3, :user))

          get "/chat/api/channels/#{direct_message_channel.id}/messages"

          expect(response.status).to eq(403)
        end

        it "skips bookmark queries" do
          queries =
            track_sql_queries do
              get "/chat/api/channels/#{channel.id}/messages"
              expect(response.status).to eq(200)
            end

          bookmark_queries = queries.select { |query| query.include?('FROM "bookmarks"') }

          expect(bookmark_queries).to be_empty
        end
      end
    end

    context "when params are invalid" do
      it "returns a 400" do
        get "/chat/api/channels/#{channel.id}/messages?page_size=0"

        expect(response.status).to eq(400)
      end
    end

    context "when readonly mode" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }

      before { Discourse.enable_readonly_mode }
      after { Discourse.disable_readonly_mode }

      it "works" do
        get "/chat/api/channels/#{channel.id}/messages"

        expect(response.status).to eq(200)
      end
    end

    context "when channel doesn’t exist" do
      it "returns a 404" do
        get "/chat/api/channels/-999/messages"

        expect(response.status).to eq(404)
      end
    end

    context "when target message doesn’t exist" do
      it "returns a 404" do
        get "/chat/api/channels/#{channel.id}/messages?target_message_id=-999"

        expect(response.status).to eq(404)
      end
    end

    context "when user can’t see channel" do
      fab!(:channel, :private_category_channel)

      it "returns a 403" do
        get "/chat/api/channels/#{channel.id}/messages"

        expect(response.status).to eq(403)
      end
    end

    context "when page_size is above limit" do
      fab!(:messages) { Fabricate.times(5, :chat_message, chat_channel: channel) }

      it "clamps it to the max" do
        stub_const(Chat::Api::ChannelMessagesController, "MAX_PAGE_SIZE", 1) do
          get "/chat/api/channels/#{channel.id}/messages?page_size=9999"

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body["messages"].size).to eq(1)
        end
      end
    end

    context "with user status enabled" do
      before { SiteSetting.enable_user_status = true }

      it "preloads user_options to avoid N+1 queries" do
        3.times do
          user = Fabricate(:user)
          Fabricate(:user_status, user:)
          msg = Fabricate(:chat_message, chat_channel: channel, user:)
          mentioned = Fabricate(:user)
          Fabricate(:user_status, user: mentioned)
          Fabricate(:user_chat_mention, chat_message: msg, user: mentioned)
        end

        get "/chat/api/channels/#{channel.id}/messages"

        queries = track_sql_queries { get "/chat/api/channels/#{channel.id}/messages" }
        user_option_queries = queries.select { |q| q.include?('"user_options"') }

        expect(user_option_queries.size).to eq(2)
      end

      it "preloads thread original message mentions to avoid N+1 queries" do
        channel.update!(threading_enabled: true)

        3.times do
          original_message = Fabricate(:chat_message, chat_channel: channel)
          thread = Fabricate(:chat_thread, channel: channel, original_message: original_message)
          mentioned = Fabricate(:user)
          mentioned.set_status!("status", "wave")
          Fabricate(:user_chat_mention, chat_message: original_message, user: mentioned)
          reply =
            Fabricate(:chat_message, chat_channel: channel, thread: thread, message: "thread reply")
          thread.update!(last_message: reply)
        end

        get "/chat/api/channels/#{channel.id}/messages"

        queries = track_sql_queries { get "/chat/api/channels/#{channel.id}/messages" }
        mention_queries =
          queries.select { |q| q.include?('"chat_mentions"') && q.include?("chat_message_id") }

        expect(mention_queries.size).to eq(1)
      end
    end
  end

  describe "#create" do
    let(:blocks) { nil }
    let(:message) { "test" }
    let(:force_thread) { nil }
    let(:in_reply_to_id) { nil }
    let(:params) do
      {
        in_reply_to_id: in_reply_to_id,
        message: message,
        blocks: blocks,
        force_thread: force_thread,
      }
    end

    before { sign_in(current_user) }

    context "when a recipient limits direct messages to specific users" do
      fab!(:recipient, :user)
      fab!(:allowed_user, :user)
      fab!(:channel) { Fabricate(:direct_message_channel, users: [current_user, recipient]) }

      before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone] }

      it "does not let an excluded existing participant send another message" do
        expect { post "/chat/#{channel.id}.json", params: params }.to change {
          channel.chat_messages.count
        }.by(1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message_id"]).to eq(channel.chat_messages.last.id)

        sign_in(recipient)
        put "/u/#{recipient.username}.json",
            params: {
              enable_allowed_pm_users: true,
              allowed_pm_usernames: allowed_user.username,
            }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("user", "id")).to eq(recipient.id)
        expect(AllowedPmUser.exists?(user: recipient, allowed_pm_user: allowed_user)).to eq(true)

        sign_in(current_user)
        expect {
          post "/chat/#{channel.id}.json", params: params.merge(message: "excluded message")
        }.not_to change { channel.chat_messages.count }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("chat.errors.not_accepting_dms", username: recipient.username),
        )
      end
    end

    context "when force_thread param is given" do
      let!(:message) { Fabricate(:chat_message, chat_channel: channel) }

      let(:force_thread) { true }
      let(:in_reply_to_id) { message.id }

      it "ignores it" do
        expect { post "/chat/#{channel.id}.json", params: params }.not_to change {
          Chat::Thread.where(force: true).count
        }
      end
    end

    context "when blocks is provided" do
      context "when user is not a bot" do
        let(:blocks) do
          [
            {
              type: "actions",
              elements: [{ type: "button", text: { type: "plain_text", text: "Click Me" } }],
            },
          ]
        end

        it "raises invalid access" do
          post "/chat/#{channel.id}.json", params: params

          expect(response.status).to eq(403)
        end
      end
    end

    context "when message is too long" do
      let(:message) { "a" * 25_000 }

      it "does not create the message" do
        expect { post "/chat/#{channel.id}.json", params: params }.not_to change {
          Chat::Message.count
        }
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to eq(
          [
            "Message is too long (maximum is #{SiteSetting.chat_maximum_message_length} characters)",
          ],
        )
      end
    end
  end

  describe "#update" do
    context "when message is updated" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel, user: current_user) }
      it "works" do
        put "/chat/api/channels/#{channel.id}/messages/#{message_1.id}",
            params: {
              message: "abcdefg",
            }

        expect(response.status).to eq(200)
        expect(message_1.reload.message).to eq("abcdefg")
      end

      context "when params are invalid" do
        it "returns a 400" do
          put "/chat/api/channels/#{channel.id}/messages/#{message_1.id}"

          expect(response.status).to eq(400)
        end
      end

      context "when message is too long" do
        it "does not change the message" do
          original_message = message_1.message

          put "/chat/api/channels/#{channel.id}/messages/#{message_1.id}",
              params: {
                message: "a" * 25_000,
              }

          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to eq(
            [
              "Message is too long (maximum is #{SiteSetting.chat_maximum_message_length} characters)",
            ],
          )
          expect(message_1.reload.message).to eq(original_message)
        end
      end

      context "when user is not part of the channel" do
        before { channel.membership_for(current_user).destroy! }

        it "returns a 404" do
          put "/chat/api/channels/#{channel.id}/messages/#{message_1.id}"

          expect(response.status).to eq(400)
        end
      end

      context "when user is not the author" do
        fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }

        it "returns a 422" do
          put "/chat/api/channels/#{channel.id}/messages/#{message_1.id}",
              params: {
                message: "abcdefg",
              }

          expect(response.status).to eq(422)
        end
      end

      context "when current user is silenced" do
        before { UserSilencer.new(current_user).silence }

        it "returns a 422" do
          put "/chat/api/channels/#{channel.id}/messages/#{message_1.id}",
              params: {
                message: "abcdefg",
              }

          expect(response.status).to eq(422)
        end
      end

      context "when the user no longer has access to a private category channel" do
        fab!(:group)
        fab!(:private_category) { Fabricate(:private_category, group:) }
        fab!(:private_channel) { Fabricate(:chat_channel, chatable: private_category) }
        fab!(:message) do
          Fabricate(
            :chat_message,
            chat_channel: private_channel,
            user: current_user,
            message: "original message",
          )
        end

        before do
          group.add(current_user)
          private_channel.add(current_user)
          GroupUser.where(group:, user: current_user).destroy_all
        end

        it "does not update their own message" do
          put "/chat/api/channels/#{private_channel.id}/messages/#{message.id}",
              params: {
                message: "edited message",
              }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body["failed"]).to eq("FAILED")
          expect(message.reload.message).to eq("original message")
        end
      end

      context "when message belongs to a different channel" do
        fab!(:other_channel, :category_channel)
        fab!(:other_message) { Fabricate(:chat_message, chat_channel: other_channel) }

        it "returns a 404" do
          put "/chat/api/channels/#{channel.id}/messages/#{other_message.id}",
              params: {
                message: "probe",
              }

          # Without channel_id scoping, the service finds the message in the
          # wrong channel and returns a non-404 status, leaking its existence
          expect(response.status).to eq(404)
        end
      end
    end
  end

  describe "#restore" do
    context "when the user no longer has access to a private category channel" do
      fab!(:group)
      fab!(:private_category) { Fabricate(:private_category, group:) }
      fab!(:private_channel) { Fabricate(:chat_channel, chatable: private_category) }
      fab!(:message) { Fabricate(:chat_message, chat_channel: private_channel, user: current_user) }

      before do
        group.add(current_user)
        private_channel.add(current_user)
        message.trash!(current_user)
        GroupUser.where(group: group, user: current_user).destroy_all
      end

      it "does not restore their own deleted message" do
        put "/chat/api/channels/#{private_channel.id}/messages/#{message.id}/restore"

        expect(response.status).to eq(403)
        expect(message.reload).to be_trashed
      end
    end

    context "when the user is no longer a member of a direct message channel" do
      fab!(:other_user, :user)
      fab!(:third_user, :user)
      fab!(:dm_channel) do
        Fabricate(:direct_message_channel, users: [current_user, other_user, third_user])
      end
      fab!(:message) { Fabricate(:chat_message, chat_channel: dm_channel, user: current_user) }

      before do
        message.trash!(current_user)
        dm_channel.chatable.direct_message_users.find_by!(user: current_user).destroy!
      end

      it "does not restore their own deleted message" do
        put "/chat/api/channels/#{dm_channel.id}/messages/#{message.id}/restore"

        expect(response.status).to eq(403)
        expect(message.reload).to be_trashed
      end
    end
  end
end
