# frozen_string_literal: true

RSpec.describe "Shortcuts | chat composer", type: :system, js: true do
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:current_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:key_modifier) { RUBY_PLATFORM =~ /darwin/i ? :meta : :control }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when using meta + l" do
    xit "handles insert link shortcut" do
    end
  end

  context "when using meta + b" do
    it "adds bold text" do
      chat.visit_channel(channel_1)

      composer = find(".chat-composer-input")
      composer.send_keys([key_modifier, "b"])

      expect(composer.value).to eq("**strong text**")
    end
  end

  context "when using meta + i" do
    it "adds italic text" do
      chat.visit_channel(channel_1)

      composer = find(".chat-composer-input")
      composer.send_keys([key_modifier, "i"])

      expect(composer.value).to eq("_emphasized text_")
    end
  end

  context "when using meta + e" do
    it "adds preformatted text" do
      chat.visit_channel(channel_1)

      composer = find(".chat-composer-input")
      composer.send_keys([key_modifier, "e"])

      expect(composer.value).to eq("`indent preformatted text by 4 spaces`")
    end
  end

  context "when the thread panel is also open" do
    fab!(:user_2) { Fabricate(:user) }
    fab!(:thread) do
      chat_thread_chain_bootstrap(
        channel: channel_1,
        users: [current_user, user_2],
        messages_count: 2,
      )
    end

    before do
      SiteSetting.enable_experimental_chat_threaded_discussions = true
      channel_1.update!(threading_enabled: true)
    end

    it "directs the shortcut to the focused composer" do
      chat.visit_channel(channel_1)
      channel_page.message_thread_indicator(thread.original_message).click

      composer = find(".chat-composer-input--channel")
      thread_composer = find(".chat-composer-input--thread")
      composer.send_keys([key_modifier, "i"])

      expect(composer.value).to eq("_emphasized text_")
      expect(thread_composer.value).to eq("")

      composer.fill_in(with: "")
      thread_composer.fill_in(with: "")

      thread_composer.send_keys([key_modifier, "i"])

      expect(composer.value).to eq("")
      expect(thread_composer.value).to eq("_emphasized text_")
    end
  end

  context "when using ArrowUp" do
    fab!(:message_1) do
      Fabricate(:chat_message, message: "message 1", chat_channel: channel_1, user: current_user)
    end
    before { Fabricate(:chat_message, message: "message 2", chat_channel: channel_1) }

    it "edits last editable message" do
      chat.visit_channel(channel_1)
      expect(channel_page).to have_message(id: message_1.id)

      find(".chat-composer-input").send_keys(:arrow_up)

      expect(page.find(".chat-composer-message-details")).to have_content(message_1.message)
    end

    context "when last message is not editable" do
      after { page.driver.browser.network_conditions = { offline: false } }

      it "does not edit a message" do
        chat.visit_channel(channel_1)
        page.driver.browser.network_conditions = { offline: true }
        channel_page.send_message("Hello world")

        find(".chat-composer-input").send_keys(:arrow_up)

        expect(page).to have_no_css(".chat-composer-message-details")
      end
    end
  end
end
