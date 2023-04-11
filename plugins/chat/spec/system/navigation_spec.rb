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
    chat_system_bootstrap(user, [category_channel, category_channel_2])
    sign_in(user)
  end

  context "when clicking chat icon and drawer is viewing channel" do
    it "navigates to index" do
      visit("/")

      chat_page.open_from_header
      chat_drawer_page.open_channel(category_channel_2)
      chat_page.open_from_header

      expect(page).to have_content(I18n.t("js.chat.direct_messages.title"))
    end
  end

  context "when clicking chat icon on mobile and is viewing channel" do
    it "navigates to index", mobile: true do
      visit("/chat")
      chat_page.visit_channel(category_channel_2)
      chat_page.open_from_header

      expect(page).to have_current_path(chat_path)
    end
  end

  context "when clicking chat icon on desktop and is viewing channel" do
    it "stays on channel page" do
      visit("/chat")
      chat_page.visit_channel(category_channel_2)
      chat_page.open_from_header

      expect(page).to have_current_path(
        chat.channel_path(category_channel_2.slug, category_channel_2.id),
      )
    end
  end

  context "when visiting /chat" do
    it "opens full page" do
      chat_page.open

      expect(page).to have_current_path(
        chat.channel_path(category_channel.slug, category_channel.id),
      )
      expect(page).to have_css("html.has-full-page-chat")
      expect(page).to have_css(".chat-message-container[data-id='#{message.id}']")
    end
  end

  context "when opening chat" do
    it "opens the drawer by default" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".chat-drawer.is-expanded")
    end
  end

  context "when opening chat with full page as preferred mode" do
    it "opens the full page" do
      visit("/")
      chat_page.open_from_header
      chat_drawer_page.maximize

      expect(page).to have_current_path(
        chat.channel_path(category_channel.slug, category_channel.id),
      )

      visit("/")
      chat_page.open_from_header

      expect(page).to have_current_path(
        chat.channel_path(category_channel.slug, category_channel.id),
      )
    end
  end

  context "when opening chat with drawer as preferred mode" do
    it "opens the full page" do
      chat_page.open
      chat_page.minimize_full_page

      expect(page).to have_css(".chat-drawer.is-expanded")

      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".chat-drawer.is-expanded")
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

  context "when sidebar is configured as the navigation menu" do
    before { SiteSetting.navigation_menu = "sidebar" }

    context "when opening channel from sidebar with drawer preferred" do
      it "opens channel in drawer" do
        visit("/t/-/#{topic.id}")
        chat_page.open_from_header
        chat_drawer_page.close
        find("a[class*='sidebar-section-link-#{category_channel.slug}']").click

        expect(page).to have_css(".chat-message-container[data-id='#{message.id}']")
      end
    end

    context "when opening channel from sidebar with full page preferred" do
      it "opens channel in full page" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.maximize
        visit("/")
        find("a[class*='sidebar-section-link-#{category_channel.slug}']").click

        expect(page).to have_current_path(
          chat.channel_path(category_channel.slug, category_channel.id),
        )
      end
    end

    context "when starting draft from sidebar with drawer preferred" do
      it "opens draft in drawer" do
        visit("/")
        sidebar_page.open_draft_channel

        expect(page).to have_current_path("/")
        expect(page).to have_css(".chat-drawer.is-expanded .direct-message-creator")
      end
    end

    context "when starting draft from drawer with drawer preferred" do
      it "opens draft in drawer" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.open_draft_channel

        expect(page).to have_current_path("/")
        expect(page).to have_css(".chat-drawer.is-expanded .direct-message-creator")
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
        expect(page).not_to have_css(".chat-drawer.is-expanded")
      end
    end

    context "when opening browse page from drawer in drawer mode" do
      it "opens browser page in full page" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.open_browse

        expect(page).to have_current_path("/chat/browse/open")
        expect(page).not_to have_css(".chat-drawer.is-expanded")
      end
    end

    context "when opening browse page from sidebar in drawer mode" do
      it "opens browser page in full page" do
        visit("/")
        chat_page.open_from_header
        sidebar_page.open_browse

        expect(page).to have_current_path("/chat/browse/open")
        expect(page).not_to have_css(".chat-drawer.is-expanded")
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
        expect(page).to have_css(".chat-drawer.is-expanded")
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
          chat.channel_path(category_channel_2.slug, category_channel_2.id),
        )
        expect(page).to have_content(category_channel_2.title)
      end
    end

    context "when opening a channel in full page" do
      fab!(:other_user) { Fabricate(:user) }
      fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user, other_user]) }

      it "activates the channel in the sidebar" do
        visit("/chat/c/#{category_channel.slug}/#{category_channel.id}")
        expect(page).to have_css(
          ".sidebar-section-link-#{category_channel.slug}.sidebar-section-link--active",
        )
      end

      it "does not have multiple channels marked active in the sidebar" do
        chat_page.visit_channel(dm_channel)
        expect(page).to have_css(
          ".sidebar-section-link-#{other_user.username}.sidebar-section-link--active",
        )

        page.find(".sidebar-section-link-#{category_channel.slug}").click
        expect(page).to have_css(
          ".sidebar-section-link-#{category_channel.slug}.sidebar-section-link--active",
        )

        expect(page).to have_css(".sidebar-section-link--active", count: 1)
      end
    end

    context "when going back to channel from channel settings in full page" do
      it "activates the channel in the sidebar" do
        visit("/chat/c/#{category_channel.slug}/#{category_channel.id}/info/settings")
        find(".chat-full-page-header__back-btn").click
        expect(page).to have_content(message.message)
      end
    end

    context "when clicking logo from a channel in full page" do
      it "deactivates the channel in the sidebar" do
        visit("/chat/c/#{category_channel.slug}/#{category_channel.id}")
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
        find("a[class*='#{category_channel.slug}']").click

        expect(page).to have_css(
          ".sidebar-section-link-#{category_channel.slug}.sidebar-section-link--active",
        )
      end
    end

    context "when closing drawer in a channel" do
      it "deactivates the channel in the sidebar" do
        visit("/")
        chat_page.open_from_header
        find("a[class*='sidebar-section-link-#{category_channel.slug}']").click
        chat_drawer_page.close

        expect(page).not_to have_css(
          ".sidebar-section-link-#{category_channel.slug}.sidebar-section-link--active",
        )
      end
    end
  end
end
