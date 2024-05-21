# frozen_string_literal: true

RSpec.describe "Chat New Message from params", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:public_channel) { Fabricate(:chat_channel) }
  fab!(:user_1_channel) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }
  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    public_channel.add(current_user)
    sign_in(current_user)
  end

  context "with a single user" do
    it "redirects to existing chat channel" do
      chat_page.visit_new_message(user_1)

      expect(page).to have_current_path("/chat/c/#{user_1.username}/#{user_1_channel.id}")
    end

    it "creates a dm channel and redirects if none exists" do
      chat_page.visit_new_message(user_2)

      expect(page).to have_current_path("/chat/c/#{user_2.username}/#{Chat::Channel.last.id}")
    end

    it "redirects to chat channel if recipients param is missing" do
      visit("/chat/new-message")

      expect(page).to have_no_current_path("/chat/new-message")
    end
  end

  context "with multiple users" do
    it "creates a dm channel with multiple users" do
      chat_page.visit_new_message([user_1, user_2])

      users = [user_1.username, user_2.username].permutation.map { |u| u.join("-") }.join("|")

      expect(page).to have_current_path(%r{/chat/c/(#{users})/#{Chat::Channel.last.id}})
    end
  end
end
