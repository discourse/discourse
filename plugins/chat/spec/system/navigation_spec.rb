# frozen_string_literal: true

RSpec.describe "Navigation", type: :system, js: true do
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user) { Fabricate(:admin) }
  fab!(:category_channel) { Fabricate(:category_channel) }
  fab!(:category_channel_2) { Fabricate(:category_channel) }
  fab!(:message) { Fabricate(:chat_message, chat_channel: category_channel) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    # ensures we have one valid registered admin
    user.activate

    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    category_channel.add(user)
    category_channel_2.add(user)

    sign_in(user)
  end

  context "when visiting /chat" do
    it "opens full page" do
      chat_page.open

      expect(page).to have_current_path(
        chat.channel_path(category_channel.id, category_channel.slug),
      )
      expect(page).to have_css("html.has-full-page-chat")
      expect(page).to have_css(".chat-message-container[data-id='#{message.id}']")
    end
  end

  context "when opening chat" do
    it "opens the drawer by default" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".topic-chat-container.expanded.visible")
    end
  end

  context "when opening chat with full page as preferred mode" do
    it "opens the full page" do
      visit("/")
      chat_page.open_from_header
      chat_drawer_page.maximize

      expect(page).to have_current_path(
        chat.channel_path(category_channel.id, category_channel.slug),
      )

      visit("/")
      chat_page.open_from_header

      expect(page).to have_current_path(
        chat.channel_path(category_channel.id, category_channel.slug),
      )
    end
  end

  context "when opening chat with drawer as preferred mode" do
    it "opens the full page" do
      chat_page.open
      chat_page.minimize_full_page

      expect(page).to have_css(".topic-chat-container.expanded.visible")

      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".topic-chat-container.expanded.visible")
    end
  end

  context "when collapsing full page with no previous state" do
    it "redirects to home page" do
      chat_page.open
      chat_page.minimize_full_page

      expect(page).to have_current_path(latest_path)
    end
  end

  context "when collapsing full page with previous state" do
    it "redirects to previous state" do
      visit("/t/-/#{topic.id}")
      chat_page.open_from_header
      chat_drawer_page.maximize
      chat_page.minimize_full_page

      expect(page).to have_current_path("/t/#{topic.slug}/#{topic.id}")
      expect(page).to have_css(".chat-message-container[data-id='#{message.id}']")
    end
  end

  context "when opening full page with a link containing a message id" do
    it "highlights correct message" do
      visit("/chat/channel/#{category_channel.id}/#{category_channel.slug}?messageId=#{message.id}")

      expect(page).to have_css(
        ".full-page-chat .chat-message-container.highlighted[data-id='#{message.id}']",
      )
    end
  end

  context "when opening drawer with a link containing a message id" do
    it "highlights correct message" do
      Fabricate(
        :post,
        topic: topic,
        raw:
          "<a href=\"/chat/channel/#{category_channel.id}/#{category_channel.slug}?messageId=#{message.id}\">foo</a>",
      )
      visit("/t/-/#{topic.id}")
      find("a", text: "foo").click

      expect(page).to have_css(
        ".topic-chat-container.expanded.visible .chat-message-container.highlighted[data-id='#{message.id}']",
      )
    end
  end

  context "when sidebar is enabled" do
    before do
      SiteSetting.enable_experimental_sidebar_hamburger = true
      SiteSetting.enable_sidebar = true
    end

    context "when opening channel from sidebar with drawer preferred" do
      it "opens channel in drawer" do
        visit("/t/-/#{topic.id}")
        chat_page.open_from_header
        chat_drawer_page.close
        find("a[title='#{category_channel.title}']").click

        expect(page).to have_css(".chat-message-container[data-id='#{message.id}']")
      end
    end

    context "when opening channel from sidebar with full page preferred" do
      it "opens channel in full page" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.maximize
        visit("/")
        find("a[title='#{category_channel.title}']").click

        expect(page).to have_current_path(
          chat.channel_path(category_channel.id, category_channel.slug),
        )
      end
    end

    context "when starting draft from sidebar with drawer preferred" do
      it "opens draft in drawer" do
        visit("/")
        sidebar_page.open_draft_channel

        expect(page).to have_current_path("/")
        expect(page).to have_css(".topic-chat-container.expanded.visible  .direct-message-creator")
      end
    end

    context "when starting draft from drawer with drawer preferred" do
      it "opens draft in drawer" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.open_draft_channel

        expect(page).to have_current_path("/")
        expect(page).to have_css(".topic-chat-container.expanded.visible .direct-message-creator")
      end
    end

    context "when starting draft from sidebar with full page preferred" do
      it "opens draft in full page" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.maximize
        visit("/")
        sidebar_page.open_draft_channel

        expect(page).to have_current_path("/chat/draft-channel")
        expect(page).not_to have_css(".topic-chat-container.expanded.visible")
      end
    end

    context "when opening browse page from drawer in drawer mode" do
      it "opens browser page in full page" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.open_browse

        expect(page).to have_current_path("/chat/browse/open")
        expect(page).not_to have_css(".topic-chat-container.expanded.visible")
      end
    end

    context "when opening browse page from sidebar in drawer mode" do
      it "opens browser page in full page" do
        visit("/")
        chat_page.open_from_header
        sidebar_page.open_browse

        expect(page).to have_current_path("/chat/browse/open")
        expect(page).not_to have_css(".topic-chat-container.expanded.visible")
      end
    end

    context "when re-opening drawer after navigating to a channel" do
      it "opens drawer on correct channel" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.open_channel(category_channel_2)
        chat_drawer_page.open_index
        chat_drawer_page.close
        chat_page.open_from_header

        expect(page).to have_current_path("/")
        expect(page).to have_css(".topic-chat-container.expanded.visible")
        expect(page).to have_content(category_channel_2.title)
      end
    end

    context "when re-opening full page chat after navigating to a channel" do
      it "opens full page chat on correct channel" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.maximize
        sidebar_page.open_channel(category_channel_2)
        find("#site-logo").click
        chat_page.open_from_header

        expect(page).to have_current_path(
          chat.channel_path(category_channel_2.id, category_channel_2.slug),
        )
        expect(page).to have_content(category_channel_2.title)
      end
    end

    context "when opening a channel in full page" do
      it "activates the channel in the sidebar" do
        visit("/chat/channel/#{category_channel.id}/#{category_channel.slug}")
        expect(page).to have_css(
          ".sidebar-section-link-#{category_channel.slug}.sidebar-section-link--active",
        )
      end
    end

    context "when clicking logo from a channel in full page" do
      it "deactivates the channel in the sidebar" do
        visit("/chat/channel/#{category_channel.id}/#{category_channel.slug}")
        find("#site-logo").click

        expect(page).not_to have_css(
          ".sidebar-section-link-#{category_channel.slug}.sidebar-section-link--active",
        )
      end
    end

    context "when opening a channel in drawer" do
      it "activates the channel in the sidebar" do
        visit("/")
        chat_page.open_from_header
        find("a[title='#{category_channel.title}']").click

        expect(page).to have_css(
          ".sidebar-section-link-#{category_channel.slug}.sidebar-section-link--active",
        )
      end
    end

    context "when closing drawer in a channel" do
      it "deactivates the channel in the sidebar" do
        visit("/")
        chat_page.open_from_header
        find("a[title='#{category_channel.title}']").click
        chat_drawer_page.close

        expect(page).not_to have_css(
          ".sidebar-section-link-#{category_channel.slug}.sidebar-section-link--active",
        )
      end
    end
  end
end
