# frozen_string_literal: true

RSpec.describe "Informative blocks in chat messages", type: :system do
  fab!(:user)
  fab!(:channel_1, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    channel_1.add(user)
    sign_in(user)
  end

  context "with a simple category element" do
    fab!(:message_1) do
      Fabricate(
        :chat_message,
        user: Discourse.system_user,
        chat_channel: channel_1,
        blocks: [
          {
            type: "informative",
            elements: [{ type: "category", title: "Support", color: "0088CC" }],
          },
        ],
      )
    end

    it "renders the category title" do
      chat_page.visit_channel(channel_1)

      expect(page).to have_css(".block__category")
      expect(page).to have_css(".badge-category__name", text: "Support")
    end
  end

  context "with a category element with description" do
    fab!(:message_1) do
      Fabricate(
        :chat_message,
        user: Discourse.system_user,
        chat_channel: channel_1,
        blocks: [
          {
            type: "informative",
            elements: [
              {
                type: "category",
                title: "Support",
                color: "0088CC",
                description: "Get help from the community",
              },
            ],
          },
        ],
      )
    end

    it "renders the category description" do
      chat_page.visit_channel(channel_1)

      expect(page).to have_css(".block__category-description", text: "Get help from the community")
    end
  end

  context "with a category element with a URL" do
    fab!(:message_1) do
      Fabricate(
        :chat_message,
        user: Discourse.system_user,
        chat_channel: channel_1,
        blocks: [
          {
            type: "informative",
            elements: [{ type: "category", title: "Support", color: "0088CC", url: "/c/support" }],
          },
        ],
      )
    end

    it "renders a link wrapping the category badge" do
      chat_page.visit_channel(channel_1)

      expect(page).to have_css("a.block__category-link[href='/c/support']")
      expect(page).to have_css("a.block__category-link .badge-category__name", text: "Support")
    end
  end

  context "with a category element with a parent category" do
    fab!(:message_1) do
      Fabricate(
        :chat_message,
        user: Discourse.system_user,
        chat_channel: channel_1,
        blocks: [
          {
            type: "informative",
            elements: [
              {
                type: "category",
                title: "Dev",
                color: "E45735",
                description: "Development related discussions",
                parent_name: "Meta",
                parent_color: "0088CC",
              },
            ],
          },
        ],
      )
    end

    it "renders the child category in the heading and parent in its own row" do
      chat_page.visit_channel(channel_1)

      expect(page).to have_css(".block__category-heading .badge-category__name", text: "Dev")
      expect(page).to have_css(".block__category-parent .badge-category__name", text: "Meta")
    end
  end

  context "with multiple category elements in one block" do
    fab!(:message_1) do
      Fabricate(
        :chat_message,
        user: Discourse.system_user,
        chat_channel: channel_1,
        blocks: [
          {
            type: "informative",
            elements: [
              { type: "category", title: "Support", color: "0088CC" },
              { type: "category", title: "Feedback", color: "25AAE2" },
            ],
          },
        ],
      )
    end

    it "renders all category elements" do
      chat_page.visit_channel(channel_1)

      expect(page).to have_css(".block__informative-item", count: 2)
      expect(page).to have_css(".badge-category__name", text: "Support")
      expect(page).to have_css(".badge-category__name", text: "Feedback")
    end
  end
end
