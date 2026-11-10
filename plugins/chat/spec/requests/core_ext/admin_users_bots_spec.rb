# frozen_string_literal: true

RSpec.describe Admin::UsersController do
  fab!(:admin)

  before { sign_in(admin) }

  describe "#create_bot" do
    it "shows the bot in chat DM search when requested" do
      post "/admin/users/bots.json",
           params: {
             bot: {
               username: "listed_bot",
               chat_discoverable: true,
             },
           }
      expect(response.status).to eq(201)
      expect(Chat::DiscoverableBot.exists?(user_id: response.parsed_body.dig("user", "id"))).to eq(
        true,
      )
    end

    it "creates unlisted bots by default or when explicitly unchecked" do
      [nil, false].each_with_index do |flag, index|
        bot_params = { username: "unlisted_bot_#{index}" }
        bot_params[:chat_discoverable] = flag unless flag.nil?
        expect { post "/admin/users/bots.json", params: { bot: bot_params } }.not_to change(
          Chat::DiscoverableBot,
          :count,
        )
        expect(response.status).to eq(201)
      end
    end

    it "ignores the setting while chat is disabled" do
      SiteSetting.chat_enabled = false
      expect do
        post "/admin/users/bots.json",
             params: {
               bot: {
                 username: "disabled_bot",
                 chat_discoverable: true,
               },
             }
      end.not_to change(Chat::DiscoverableBot, :count)
      expect(response.status).to eq(201)
    end
  end
end
