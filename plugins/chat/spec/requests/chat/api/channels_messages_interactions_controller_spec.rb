# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsMessagesInteractionsController do
  fab!(:current_user, :user)
  fab!(:channel, :private_category_channel)
  fab!(:message) do
    Fabricate(
      :chat_message,
      chat_channel: channel,
      user: Discourse.system_user,
      blocks: [
        {
          type: "actions",
          elements: [
            {
              action_id: "xxx",
              value: "foo",
              type: "button",
              text: {
                type: "plain_text",
                text: "Click Me",
              },
            },
          ],
        },
      ],
    )
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#create" do
    context "when user has access to the channel" do
      fab!(:accessible_channel, :category_channel)
      fab!(:accessible_message) do
        Fabricate(
          :chat_message,
          chat_channel: accessible_channel,
          user: Discourse.system_user,
          blocks: [
            {
              type: "actions",
              elements: [
                {
                  action_id: "xxx",
                  value: "foo",
                  type: "button",
                  text: {
                    type: "plain_text",
                    text: "Click Me",
                  },
                },
              ],
            },
          ],
        )
      end

      before { accessible_channel.add(current_user) }

      it "creates an interaction and returns serialized data" do
        post "/chat/api/channels/#{accessible_channel.id}/messages/#{accessible_message.id}/interactions",
             params: {
               action_id: "xxx",
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body["interaction"]).to include(
          "user" => hash_including("id" => current_user.id),
          "message" => hash_including("id" => accessible_message.id),
          "channel" => hash_including("id" => accessible_channel.id),
          "action" => hash_including("action_id" => "xxx"),
        )
      end

      it "does not expose action values in the response" do
        post "/chat/api/channels/#{accessible_channel.id}/messages/#{accessible_message.id}/interactions",
             params: {
               action_id: "xxx",
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("interaction", "action")).not_to have_key("value")
      end

      it "returns 404 when action_id does not match any block element" do
        post "/chat/api/channels/#{accessible_channel.id}/messages/#{accessible_message.id}/interactions",
             params: {
               action_id: "nonexistent",
             }

        expect(response.status).to eq(404)
      end

      it "returns 400 when action_id is missing" do
        post "/chat/api/channels/#{accessible_channel.id}/messages/#{accessible_message.id}/interactions",
             params: {
             }

        expect(response.status).to eq(400)
      end
    end

    context "when user has read-only access to the category channel" do
      fab!(:read_only_group, :group)
      fab!(:read_only_category) do
        Fabricate(
          :private_category,
          group: read_only_group,
          permission_type: CategoryGroup.permission_types[:readonly],
        )
      end
      fab!(:read_only_channel) { Fabricate(:category_channel, chatable: read_only_category) }
      fab!(:read_only_message) do
        Fabricate(
          :chat_message,
          chat_channel: read_only_channel,
          user: Discourse.system_user,
          blocks: [
            {
              type: "actions",
              elements: [
                {
                  action_id: "xxx",
                  value: "foo",
                  type: "button",
                  text: {
                    type: "plain_text",
                    text: "Click Me",
                  },
                },
              ],
            },
          ],
        )
      end

      before { read_only_group.add(current_user) }

      it "returns 404 and does not create an interaction" do
        expect do
          post "/chat/api/channels/#{read_only_channel.id}/messages/#{read_only_message.id}/interactions",
               params: {
                 action_id: "xxx",
               }
        end.not_to change(Chat::MessageInteraction, :count)

        expect(response.status).to eq(404)
        expect(response.parsed_body).to include(
          "errors" => [I18n.t("not_found")],
          "error_type" => "not_found",
        )
      end
    end

    context "when user is not logged in" do
      before { sign_out }

      it "returns 404" do
        post "/chat/api/channels/#{channel.id}/messages/#{message.id}/interactions",
             params: {
               action_id: "xxx",
             }

        expect(response.status).to eq(404)
      end
    end

    context "when chat is disabled" do
      before { SiteSetting.chat_enabled = false }

      it "returns 404" do
        post "/chat/api/channels/#{channel.id}/messages/#{message.id}/interactions",
             params: {
               action_id: "xxx",
             }

        expect(response.status).to eq(404)
      end
    end

    context "when message exists in a channel the user cannot access" do
      it "returns 404 to avoid leaking message existence" do
        post "/chat/api/channels/#{channel.id}/messages/#{message.id}/interactions",
             params: {
               action_id: "xxx",
             }

        expect(response.status).to eq(404)
      end
    end

    context "when message does not exist" do
      it "returns 404" do
        post "/chat/api/channels/#{channel.id}/messages/-999/interactions",
             params: {
               action_id: "xxx",
             }

        expect(response.status).to eq(404)
      end
    end

    context "when message exists but in a different channel than the URL" do
      fab!(:other_channel, :category_channel)

      before { other_channel.add(current_user) }

      it "returns 404 to avoid cross-channel message lookup" do
        post "/chat/api/channels/#{other_channel.id}/messages/#{message.id}/interactions",
             params: {
               action_id: "xxx",
             }

        expect(response.status).to eq(404)
      end
    end
  end
end
