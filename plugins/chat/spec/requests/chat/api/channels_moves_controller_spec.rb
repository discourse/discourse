# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsMessagesMovesController do
  fab!(:channel) { Fabricate(:category_channel) }

  70.times { |n| fab!("message_#{n}") { Fabricate(:chat_message, chat_channel: channel) } }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  def flag_message(message, flagger, flag_type: ReviewableScore.types[:off_topic])
    Chat::ReviewQueue.new.flag_message(message, Guardian.new(flagger), flag_type)[:reviewable]
  end

  describe "#create" do
    fab!(:message_to_move_1) do
      Fabricate(:chat_message, chat_channel: channel, created_at: 2.minutes.ago)
    end
    fab!(:message_to_move_2) do
      Fabricate(:chat_message, chat_channel: channel, created_at: 1.minute.ago)
    end
    fab!(:destination_channel) { Fabricate(:category_channel) }
    let(:message_ids) { [message_to_move_1.id, message_to_move_2.id] }

    context "when the user is not admin" do
      before { sign_in(Fabricate(:user)) }

      it "returns an access denied error" do
        post "/chat/api/channels/#{channel.id}/messages/moves",
             params: {
               move: {
                 destination_channel_id: destination_channel.id,
                 message_ids: message_ids,
               },
             }
        expect(response.status).to eq(403)
      end
    end

    context "when the user is admin" do
      fab!(:current_user) { Fabricate(:admin) }

      before { sign_in(current_user) }

      it "shows an error if the source channel is not found" do
        channel.trash!
        post "/chat/api/channels/#{channel.id}/messages/moves",
             params: {
               move: {
                 destination_channel_id: destination_channel.id,
                 message_ids: message_ids,
               },
             }
        expect(response.status).to eq(404)
      end

      it "shows an error if the destination channel is not found" do
        destination_channel.trash!
        post "/chat/api/channels/#{channel.id}/messages/moves",
             params: {
               move: {
                 destination_channel_id: destination_channel.id,
                 message_ids: message_ids,
               },
             }
        expect(response.status).to eq(404)
      end

      it "successfully moves the messages to the new channel" do
        post "/chat/api/channels/#{channel.id}/messages/moves",
             params: {
               move: {
                 destination_channel_id: destination_channel.id,
                 message_ids: message_ids,
               },
             }
        expect(response.status).to eq(200)
        latest_destination_messages = destination_channel.chat_messages.last(2)
        expect(latest_destination_messages.first.message).to eq(message_to_move_1.message)
        expect(latest_destination_messages.second.message).to eq(message_to_move_2.message)
        expect(message_to_move_1.reload.deleted_at).not_to eq(nil)
        expect(message_to_move_2.reload.deleted_at).not_to eq(nil)
      end

      it "shows an error message when the destination channel is invalid" do
        invalid_channel = Fabricate(:direct_message_channel, users: [current_user])

        post "/chat/api/channels/#{channel.id}/messages/moves",
             params: {
               move: {
                 destination_channel_id: invalid_channel.id,
                 message_ids: message_ids,
               },
             }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("chat.errors.message_move_invalid_channel"),
        )
      end

      it "shows an error when none of the messages can be found" do
        destroyed_message = Fabricate(:chat_message, chat_channel: channel)
        destroyed_message.trash!

        post "/chat/api/channels/#{channel.id}/messages/moves",
             params: {
               move: {
                 destination_channel_id: destination_channel.id,
                 message_ids: [destroyed_message],
               },
             }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("chat.errors.message_move_no_messages_found"),
        )
      end
    end
  end
end
