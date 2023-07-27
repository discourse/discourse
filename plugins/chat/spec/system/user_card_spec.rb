# frozen_string_literal: true

RSpec.describe "User card", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:topic_1) { Fabricate(:topic) }

  let(:chat) { PageObjects::Pages::Chat.new }

  before { chat_system_bootstrap }

  shared_examples "not showing chat button" do
    it "doesn’t show the chat buttton" do
      expect(page).to have_no_css(".chat-user-card-btn")
    end
  end

  shared_examples "showing chat button" do
    it "shows the chat buttton" do
      expect(page).to have_css(".chat-user-card-btn")
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
          find("[data-user-card='#{topic_1.user.username}'").click
        end

        include_examples "not showing chat button"
      end
    end

    context "when chat enabled" do
      before { sign_in(current_user) }

      context "when showing user card" do
        before do
          visit("/")
          find("[data-user-card='#{topic_1.user.username}'").click
        end

        include_examples "showing chat button"

        context "when clicking chat button" do
          before { find(".chat-user-card-btn").click }

          it "opens correct channel" do
            # at this point the ChatChannel is not created yet
            expect(page).to have_css(".chat-drawer.is-expanded")
            expect(page).to have_css(
              ".chat-drawer.is-expanded[data-chat-channel-id='#{Chat::Channel.last.id}']",
            )
          end
        end
      end
    end
  end

  context "when anonymous" do
    context "when showing user card" do
      before do
        visit("/")
        find("[data-user-card='#{topic_1.user.username}'").click
      end

      include_examples "not showing chat button"
    end
  end
end
