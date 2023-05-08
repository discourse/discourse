# frozen_string_literal: true

RSpec.describe "Channel selector modal", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:key_modifier) { RUBY_PLATFORM =~ /darwin/i ? :meta : :control }

  before do
    chat_system_bootstrap
    sign_in(current_user)
    visit("/")
  end

  context "when used with public channel" do
    fab!(:channel_1) { Fabricate(:category_channel) }

    it "works" do
      find("body").send_keys([key_modifier, "k"])
      find("#chat-channel-selector-input").fill_in(with: channel_1.title)
      find(".chat-channel-selection-row[data-id='#{channel_1.id}']").click

      channel_page.send_message("Hello world")

      expect(channel_page).to have_message(text: "Hello world")
    end
  end

  context "when used with user" do
    fab!(:user_1) { Fabricate(:user) }

    it "works" do
      find("body").send_keys([key_modifier, "k"])
      find("#chat-channel-selector-input").fill_in(with: user_1.username)
      find(".chat-channel-selection-row[data-id='#{user_1.id}']").click

      channel_page.send_message("Hello world")

      expect(channel_page).to have_message(text: "Hello world")
    end
  end

  context "when used with dm channel" do
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

    it "works" do
      find("body").send_keys([key_modifier, "k"])
      find("#chat-channel-selector-input").fill_in(with: current_user.username)
      find(".chat-channel-selection-row[data-id='#{dm_channel_1.id}']").click
      channel_page.send_message("Hello world")

      expect(channel_page).to have_message(text: "Hello world")
    end
  end

  context "when on a channel" do
    fab!(:channel_1) { Fabricate(:category_channel) }

    it "it doesn’t include current channel" do
      chat_page.visit_channel(channel_1)
      find("body").send_keys([key_modifier, "k"])
      find("#chat-channel-selector-input").click

      expect(page).to have_no_css(".chat-channel-selection-row[data-id='#{channel_1.id}']")
    end
  end

  context "with limited access channels" do
    fab!(:group_1) { Fabricate(:group) }
    fab!(:channel_1) { Fabricate(:private_category_channel, group: group_1) }

    it "it doesn’t include limited access channel" do
      find("body").send_keys([key_modifier, "k"])
      find("#chat-channel-selector-input").fill_in(with: channel_1.title)

      expect(page).to have_no_css(".chat-channel-selection-row[data-id='#{channel_1.id}']")
    end
  end
end
