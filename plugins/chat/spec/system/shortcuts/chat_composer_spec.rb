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
    xit "adds bold text" do
      chat.visit_channel(channel_1)

      within(".chat-composer-input") do |composer|
        composer.send_keys([key_modifier, "b"])

        expect(composer.value).to eq("**strong text**")
      end
    end
  end

  context "when using meta + i" do
    xit "adds italic text" do
      chat.visit_channel(channel_1)

      within(".chat-composer-input") do |composer|
        composer.send_keys([key_modifier, "i"])

        expect(composer.value).to eq("_emphasized text_")
      end
    end
  end

  context "when using meta + e" do
    it "adds preformatted text" do
      chat.visit_channel(channel_1)

      within(".chat-composer-input") do |composer|
        composer.send_keys([key_modifier, "e"])

        expect(composer.value).to eq("`indent preformatted text by 4 spaces`")
      end
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
  end
end
