# frozen_string_literal: true

describe "Search | Shortcuts for variations of search input", type: :system do
  fab!(:current_user, :user)

  let(:welcome_banner) { PageObjects::Components::WelcomeBanner.new }
  let(:search_page) { PageObjects::Pages::Search.new }

  before { sign_in(current_user) }

  context "when search_experience is search_field" do
    before do
      Fabricate(:theme_site_setting_with_service, name: "search_experience", value: "search_field")
    end

    context "when enable_welcome_banner is true" do
      before do
        Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: true)
      end

      it "displays and focuses welcome banner search when / is pressed and hides it when Escape is pressed" do
        visit("/")
        expect(welcome_banner).to be_visible
        send_keys("/")
        expect(search_page).to have_search_menu
        expect(page).to have_css("#welcome-banner-search-input:focus")
        send_keys(:escape)
        expect(search_page).to have_no_search_menu_visible
      end

      context "when welcome banner is not in the viewport" do
        it "displays and focuses header search when / is pressed and hides it when Escape is pressed" do
          visit("/")
          expect(welcome_banner).to be_visible
          fake_scroll_down_long
          expect(search_page).to have_search_field
          expect(welcome_banner).to be_invisible
          send_keys("/")
          expect(search_page).to have_search_menu
          expect(page).to have_css("#header-search-input:focus")
          send_keys(:escape)
          expect(search_page).to have_no_search_menu_visible
        end
      end
    end

    context "when enable_welcome_banner is false" do
      before do
        Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
      end

      it "displays and focuses header search when / is pressed and hides it when Escape is pressed" do
        visit("/")
        expect(welcome_banner).to be_hidden
        send_keys("/")
        expect(search_page).to have_search_menu
        expect(page).to have_css("#header-search-input:focus")
        send_keys(:escape)
        expect(search_page).to have_no_search_menu_visible
      end
    end
  end

  context "when search_experience is search_icon" do
    before do
      Fabricate(:theme_site_setting_with_service, name: "search_experience", value: "search_icon")
    end

    context "when enable_welcome_banner is true" do
      before do
        Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: true)
      end

      it "displays and focuses welcome banner search when / is pressed and hides it when Escape is pressed" do
        visit("/")
        expect(welcome_banner).to be_visible
        send_keys("/")
        expect(search_page).to have_search_menu
        expect(page).to have_css("#welcome-banner-search-input:focus")
        send_keys(:escape)
        expect(search_page).to have_no_search_menu_visible
      end

      context "when welcome banner is not in the viewport" do
        it "displays and focuses search icon search when / is pressed and hides it when Escape is pressed" do
          visit("/")
          expect(welcome_banner).to be_visible
          fake_scroll_down_long
          expect(search_page).to have_search_icon
          expect(welcome_banner).to be_invisible
          send_keys("/")
          expect(search_page).to have_search_menu
          expect(page).to have_css("#icon-search-input:focus")
          send_keys(:escape)
          expect(search_page).to have_no_search_menu_visible
        end
      end
    end

    context "when enable_welcome_banner is false" do
      before do
        Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
      end

      it "displays and focuses search icon search when / is pressed and hides it when Escape is pressed" do
        visit("/")
        expect(welcome_banner).to be_hidden
        send_keys("/")
        expect(search_page).to have_search_menu
        expect(page).to have_css("#icon-search-input:focus")
        send_keys(:escape)
        expect(search_page).to have_no_search_menu_visible
      end

      # This search menu only shows within a topic, not in other pages on the site,
      # unlike header search which is always visible.
      context "when within a topic with 20+ posts" do
        fab!(:topic)
        fab!(:posts) { Fabricate.times(21, :post, topic: topic) }

        it "opens search on first press of /, and closes when Escape is pressed" do
          visit "/t/#{topic.slug}/#{topic.id}"
          send_keys("/")
          expect(search_page).to have_search_menu
          expect(page).to have_css("#icon-search-input:focus")
          send_keys(:escape)
          expect(search_page).to have_no_search_menu_visible
        end
      end
    end
  end
end
