# frozen_string_literal: true

RSpec.describe "Discourse Math - chat message", type: :system do
  fab!(:current_user, :admin)
  fab!(:channel, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.discourse_math_enabled = true
    chat_system_bootstrap
    channel.add(current_user)
    sign_in(current_user)
  end

  describe "MathJax provider" do
    before { SiteSetting.discourse_math_provider = "mathjax" }

    it "renders math in chat messages" do
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: current_user,
        message: "Check this: $E=mc^2$",
      )

      chat_page.visit_channel(channel)

      expect(page).to have_css(".chat-message-text .math-container mjx-container", wait: 10)
    end
  end

  describe "KaTeX provider" do
    before { SiteSetting.discourse_math_provider = "katex" }

    it "renders math in chat messages" do
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: current_user,
        message: "Check this: $x^2$",
      )

      chat_page.visit_channel(channel)

      expect(page).to have_css(".chat-message-text .math-container .katex", wait: 10)
    end
  end
end
