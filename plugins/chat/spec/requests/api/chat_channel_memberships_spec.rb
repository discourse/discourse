# frozen_string_literal: true

require "rails_helper"

describe Chat::Api::ChatChannelMembershipsController do
  fab!(:user_1) { Fabricate(:user, username: "bob") }
  fab!(:user_2) { Fabricate(:user, username: "clark") }
  fab!(:channel_1) { Fabricate(:category_channel) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#index" do
    include_examples "channel access example", :get, "/memberships.json"

    context "when memberships exist" do
      before do
        UserChatChannelMembership.create(user: user_1, chat_channel: channel_1, following: true)
        UserChatChannelMembership.create(
          user: Fabricate(:user),
          chat_channel: channel_1,
          following: false,
        )
        UserChatChannelMembership.create(user: user_2, chat_channel: channel_1, following: true)
        sign_in(user_1)
      end

      it "lists followed memberships" do
        get "/chat/api/chat_channels/#{channel_1.id}/memberships.json"

        expect(response.parsed_body.length).to eq(2)
        expect(response.parsed_body[0]["user"]["id"]).to eq(user_1.id)
        expect(response.parsed_body[1]["user"]["id"]).to eq(user_2.id)
      end
    end
  end
end
