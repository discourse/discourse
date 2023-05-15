# frozen_string_literal: true

RSpec.describe "Navigating to message", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }
  fab!(:first_message) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:link) { "My favorite message" }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    75.times { Fabricate(:chat_message, chat_channel: channel_1) }
    sign_in(current_user)
  end

  context "when in full page mode" do
    before { chat_page.prefers_full_page }

    context "when clicking a link containing a message id" do
      fab!(:topic_1) { Fabricate(:topic) }

      before do
        Fabricate(
          :post,
          topic: topic_1,
          raw: "<a href=\"/chat/c/-/#{channel_1.id}/#{first_message.id}\">#{link}</a>",
        )
      end

      it "highlights the correct message" do
        visit("/t/-/#{topic_1.id}")
        click_link(link)

        expect(page).to have_css(
          ".chat-message-container.highlighted[data-id='#{first_message.id}']",
        )
      end
    end

    context "when clicking a link to a message from the current channel" do
      before do
        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          message: "[#{link}](/chat/c/-/#{channel_1.id}/#{first_message.id})",
        )
      end

      it "highlights the correct message" do
        chat_page.visit_channel(channel_1)
        click_link(link)

        expect(page).to have_css(
          ".chat-message-container.highlighted[data-id='#{first_message.id}']",
        )
      end

      it "highlights the correct message after using the bottom arrow" do
        chat_page.visit_channel(channel_1)

        click_link(link)

        expect(page).to have_css(
          ".chat-message-container.highlighted[data-id='#{first_message.id}']",
        )

        click_button(class: "chat-scroll-to-bottom")

        expect(page).to have_content(link, visible: :all)

        click_link(link)

        expect(page).to have_css(
          ".chat-message-container.highlighted[data-id='#{first_message.id}']",
        )
      end
    end

    context "when clicking a link to a message from another channel" do
      fab!(:channel_2) { Fabricate(:category_channel) }

      before do
        Fabricate(
          :chat_message,
          chat_channel: channel_2,
          message: "[#{link}](/chat/c/-/#{channel_1.id}/#{first_message.id})",
        )
        channel_2.add(current_user)
      end

      it "highlights the correct message" do
        chat_page.visit_channel(channel_2)
        click_link(link)

        expect(page).to have_css(
          ".chat-message-container.highlighted[data-id='#{first_message.id}']",
        )
      end
    end

    context "when navigating directly to a message link" do
      it "highglights the correct message" do
        visit("/chat/c/-/#{channel_1.id}/#{first_message.id}")

        expect(page).to have_css(
          ".chat-message-container.highlighted[data-id='#{first_message.id}']",
        )
      end
    end
  end

  context "when in drawer" do
    context "when clicking a link containing a message id" do
      fab!(:topic_1) { Fabricate(:topic) }

      before do
        Fabricate(
          :post,
          topic: topic_1,
          raw: "<a href=\"/chat/c/-/#{channel_1.id}/#{first_message.id}\">#{link}</a>",
        )
      end

      it "highlights correct message" do
        visit("/t/-/#{topic_1.id}")
        click_link(link)

        expect(page).to have_css(
          ".chat-drawer.is-expanded .chat-message-container.highlighted[data-id='#{first_message.id}']",
        )
      end
    end

    context "when clicking a link to a message from the current channel" do
      before do
        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          message: "[#{link}](/chat/c/-/#{channel_1.id}/#{first_message.id})",
        )
      end

      it "highlights the correct message" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.open_channel(channel_1)
        click_link(link)

        expect(page).to have_css(
          ".chat-message-container.highlighted[data-id='#{first_message.id}']",
        )
      end

      it "highlights the correct message after using the bottom arrow" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.open_channel(channel_1)

        click_link(link)
        click_button(class: "chat-scroll-to-bottom")
        click_link(link)

        expect(page).to have_css(
          ".chat-message-container.highlighted[data-id='#{first_message.id}']",
        )
      end
    end
  end
end
