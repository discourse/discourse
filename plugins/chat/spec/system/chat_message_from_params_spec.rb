# frozen_string_literal: true

RSpec.describe "Chat from URL params", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "with a single user" do
    it "redirects to existing chat channel" do
      visit("/chat/new-message?username=#{user_1.username}")

      expect(page).to have_current_path("/chat/c/#{user_1.username}/#{dm_channel.id}")
    end

    it "creates a dm channel and redirects if none exists" do
      visit("/chat/new-message?username=#{user_2.username}")

      expect(page).to have_current_path("/chat/c/#{user_2.username}/#{Chat::Channel.last.id}")
    end

    it "redirects to chat home if username param is missing" do
      visit("/chat/new-message?abc=def")

      # chat selects the first dm channel by default
      expect(page).to have_current_path("/chat/c/#{user_1.username}/#{dm_channel.id}")
    end
  end

  context "with multiple users" do
    it "creates a dm channel with multiple users" do
      visit("/chat/new-message?username=#{user_1.username},#{user_2.username}")

      expect(page).to have_current_path(
        "/chat/c/#{user_1.username}-#{user_2.username}/#{Chat::Channel.last.id}",
      )
    end
  end
end
