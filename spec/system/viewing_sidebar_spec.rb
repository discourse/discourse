# frozen_string_literal: true

describe "Viewing sidebar" do
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  context "as logged in user" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:category_sidebar_section_link) { Fabricate(:category_sidebar_section_link, user: user) }

    before { sign_in(user) }

    describe "when using the header dropdown navigation menu" do
      before { SiteSetting.navigation_menu = "header dropdown" }

      it "shows the sidebar while preserving the header dropdown" do
        browser_page
          .goto("/latest?navigation_menu=sidebar")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(sidebar).to RSpecPredicates.be_visible
        expect(browser_root.locator(".hamburger-dropdown").filter(visible: true)).not_to have_count(
          0,
        )
      end
    end

    describe "when using the sidebar navigation menu" do
      before { SiteSetting.navigation_menu = "sidebar" }

      it "shows the header dropdown selected by the query parameter" do
        browser_page
          .goto("/latest?navigation_menu=header_dropdown")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(sidebar).to be_not_visible

        header_dropdown = PageObjects::Components::SidebarHeaderDropdown.new
        header_dropdown.click

        expect(header_dropdown).to RSpecPredicates.be_visible
      end
    end

    describe "Community sidebar section" do
      fab!(:user) { Fabricate(:user, locale: "pl_PL") }
      fab!(:translation_override) do
        TranslationOverride.create!(
          locale: "pl_PL",
          translation_key: "js.sidebar.sections.community.links.topics.content",
          value: "Tematy",
        )
        TranslationOverride.create!(
          locale: "pl_PL",
          translation_key: "js.sidebar.sections.community.links.topics.title",
          value: "Wszystkie tematy",
        )
      end

      before { SiteSetting.allow_user_locale = true }

      it "has correct translations" do
        sign_in user
        browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        links =
          browser_root
            .locator("#sidebar-section-content-community .sidebar-section-link-wrapper a")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
        expect(links.map { |element| element.inner_text.strip }[0]).to eq("Tematy")
        expect(links.map { |link| link[:title] }[0]).to eq("Wszystkie tematy")
      end
    end

    describe "when viewing the 'more' content in the Community sidebar section" do
      let(:more_trigger_selector) do
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-trigger"
      end
      let(:more_links_selector) do
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-content"
      end

      it "toggles the more menu and handles click outside to close it" do
        browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        browser_root.locator(more_trigger_selector).filter(visible: true).click

        expect(browser_root.locator(more_links_selector).filter(visible: true)).not_to have_count(0)

        expect(
          browser_root.locator("#{more_trigger_selector}[aria-expanded='true']").filter(
            visible: true,
          ),
        ).not_to have_count(0)

        browser_root.locator(more_trigger_selector).filter(visible: true).click

        expect(browser_root.locator(more_links_selector).filter(visible: true)).to have_count(0)

        expect(
          browser_root.locator("#{more_trigger_selector}[aria-expanded='false']").filter(
            visible: true,
          ),
        ).not_to have_count(0)

        browser_root.locator(more_trigger_selector).filter(visible: true).click

        browser_root.locator(".d-header-wrap").filter(visible: true).click

        expect(browser_root.locator(more_links_selector).filter(visible: true)).to have_count(0)
      end
    end

    describe "when viewing the tags section" do
      fab!(:tag1) do
        Fabricate(:tag, name: "tag 1", description: "tag 1 description <script>").tap do |tag|
          Fabricate.times(1, :topic, tags: [tag])
        end
      end

      fab!(:tag2) do
        Fabricate(:tag, name: "tag 2").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
      end

      fab!(:tag3) do
        Fabricate(:tag, name: "tag 3", description: "tag 3 description").tap do |tag|
          Fabricate.times(3, :topic, tags: [tag])
        end
      end

      fab!(:tag4) do
        Fabricate(:tag, name: "tag 4").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
      end

      fab!(:tag5) do
        Fabricate(:tag, name: "tag 5").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
      end

      fab!(:tag6) do
        Fabricate(:tag, name: "tag 6").tap { |tag| Fabricate.times(1, :topic, tags: [tag]) }
      end

      it "hides the tags section when tagging is disabled" do
        SiteSetting.tagging_enabled = false

        browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(sidebar).to RSpecPredicates.be_visible
        expect(sidebar).to have_no_tags_section
      end

      it "hides the tags section when no tags are visible" do
        Tag.delete_all

        browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(sidebar).to RSpecPredicates.be_visible
        expect(sidebar).to have_no_tags_section
      end

      it "shows top tags when the user has not configured tags" do
        browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(sidebar).to RSpecPredicates.be_visible
        expect(sidebar).to have_tags_section
        expect(sidebar).to have_tag_section_links([tag3, tag2, tag4, tag5, tag1])
        expect(sidebar).to have_all_tags_section_link
      end

      it "shows the user's tags in alphabetical order" do
        Fabricate(:sidebar_section_link, linkable: tag3, user: user)
        Fabricate(:sidebar_section_link, linkable: tag1, user: user)
        Fabricate(:sidebar_section_link, linkable: tag2, user: user)

        browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(sidebar).to RSpecPredicates.be_visible
        expect(sidebar).to have_tags_section
        expect(sidebar).to have_tag_section_links([tag1, tag2, tag3])
        expect(sidebar).to have_all_tags_section_link
      end
    end

    describe "when My messages sidebar link" do
      it "shows for a user who can send private messages" do
        sign_in(admin)
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(sidebar).to have_my_messages_link
      end

      it "hides from a user who cannot send private messages" do
        SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:admins]
        sign_in(user)
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(sidebar).to have_no_my_messages_link
      end

      context "with translation override" do
        fab!(:translation_override) do
          TranslationOverride.upsert!(
            "en",
            "js.sidebar.sections.community.links.my_messages.content",
            "Overrided",
          )
        end

        it "is translated" do
          sign_in(admin)
          browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(sidebar).to have_my_messages_link("Overrided")
        end
      end

      describe "has unread messages" do
        fab!(:private_message) do
          Fabricate(:private_message_post, user: user, recipient: admin).topic
        end
        let(:user_private_messages_page) { PageObjects::Pages::UserPrivateMessages.new }

        it "shows the new-messages indicator" do
          sign_in(admin)
          browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(sidebar).to have_my_messages_link_with_unread_icon
        end

        it "shows the new-item count" do
          admin.user_option.update!(sidebar_show_count_of_new_items: true)
          sign_in(admin)
          browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(sidebar).to have_my_messages_link_with_unread_count
        end

        it "removes the unread icon after every message is read" do
          sign_in(admin)
          user_private_messages_page.visit(admin)
          user_private_messages_page.click_unseen_private_message(private_message.id)
          expect(sidebar).to have_my_messages_link_with_unread_icon

          try_until_success(reason: "Liking relying on messagebus updates") do
            expect(sidebar).to have_my_messages_link_without_unread_icon
          end
        end
      end
    end

    it "hides the panel header in the main sidebar" do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(sidebar).to RSpecPredicates.be_visible
      expect(sidebar).to have_no_panel_header
    end
  end

  context "as anonymous user" do
    describe "My messages sidebar link" do
      it "hides from anonymous users" do
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(sidebar).to have_no_my_messages_link
      end
    end
  end
end
