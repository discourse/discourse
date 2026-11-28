# frozen_string_literal: true

RSpec.describe "User card" do
  fab!(:current_user, :user)
  fab!(:topic_1, :topic)

  let(:chat) { PageObjects::Pages::Chat.new }

  before { chat_system_bootstrap }

  shared_examples "not showing chat button" do
    it "doesn’t show the chat button" do
      expect(page).to have_no_css(".chat-direct-message-btn")
    end
  end

  context "when user" do
    context "when chat disabled" do
      before do
        SiteSetting.chat_enabled = false
        sign_in(current_user)
      end

      context "when showing user card" do
        before do
          visit("/")
          find("[data-user-card='#{topic_1.user.username}']").click
          expect(page).to have_css(".user-card.show")
        end

        include_examples "not showing chat button"
      end
    end

    context "when chat enabled" do
      before { sign_in(current_user) }

      context "when showing user card" do
        before do
          visit("/")
          find("[data-user-card='#{topic_1.user.username}']").click
          expect(page).to have_css(".user-card.show")
        end

        it "shows the chat button and opens a DM with the user on the card" do
          expect(page).to have_css(".chat-direct-message-btn")
          find(".chat-direct-message-btn").click

          expect(chat).to have_drawer
          direct_message = Chat::DirectMessage.for_user_ids([current_user.id, topic_1.user_id])
          expect(chat).to have_drawer(channel_id: direct_message.direct_message_channel.id)
        end
      end
    end
  end

  context "when anonymous" do
    context "when showing user card" do
      before do
        visit("/")
        find("[data-user-card='#{topic_1.user.username}']").click
        expect(page).to have_css(".user-card.show")
      end

      include_examples "not showing chat button"
    end
  end
end
