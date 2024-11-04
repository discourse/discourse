# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelMessagesController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:chat_channel) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel.add(current_user)
    sign_in(current_user)
  end

  describe "#index" do
    describe "success" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }
      fab!(:message_2) { Fabricate(:chat_message) }

      it "works" do
        get "/chat/api/channels/#{channel.id}/messages"

        expect(response.status).to eq(200)
        expect(response.parsed_body["messages"].map { |m| m["id"] }).to contain_exactly(
          message_1.id,
        )
      end
    end

    context "when params are invalid" do
      it "returns a 400" do
        get "/chat/api/channels/#{channel.id}/messages?page_size=9999"

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
      fab!(:channel) { Fabricate(:private_category_channel) }

      it "returns a 403" do
        get "/chat/api/channels/#{channel.id}/messages"

        expect(response.status).to eq(403)
      end
    end
  end

  describe "#create" do
    context "when force_thread param is given" do
      let!(:message) { Fabricate(:chat_message, chat_channel: channel) }

      before { sign_in(current_user) }

      it "ignores it" do
        expect {
          post "/chat/#{channel.id}.json",
               params: {
                 in_reply_to_id: message.id,
                 message: "test",
                 force_thread: true,
               }
        }.not_to change { Chat::Thread.where(force: true).count }
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
    end
  end
end
