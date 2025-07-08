# frozen_string_literal: true

module PageObjects
  module Pages
    class Search < PageObjects::Pages::Base
      def type_in_search(input)
        filter = find("input.full-page-search")
        filter.click
        filter.send_keys(:end)
        filter.send_keys(input)
        self
      end

      def type_in_search_menu(input)
        find(".search-input--header input").send_keys(input)
        self
      end

      def sort_order
        PageObjects::Components::SelectKit.new("#search-sort-by")
      end

      def click_search_menu_link
        find(".search-menu .results .search-link").click
      end

      def clear_search_input
        find("input.full-page-search").set("")
        self
      end

      def search_input
        find("input.full-page-search")
      end

      def has_heading_text?(text)
        has_selector?("h1.search-page-heading", text: text)
      end

      def has_no_heading_text?(text)
        has_no_selector?("h1.search-page-heading", text: text)
      end

      def click_search_button
        find(".search-cta").click
      end

      def expand_dropdown
        click_search_icon if !has_css?(".search-menu .search-menu-panel", wait: 0)
        self
      end

      def click_search_icon
        find(".d-header #search-button").click
        has_css?(is_mobile? ? ".search-container" : ".search-menu-container")
        self
      end

      def click_in_posts_by_user
        find(".search-menu-container .search-menu-assistant-item").click
      end

      def click_first_topic
        find(".topic-list-body tr:first-of-type").click
      end

      def has_search_menu_visible?
        page.has_css?(".search-menu .search-menu-panel", visible: true)
      end

      # This is used for cases like header and welcome banner search,
      # where we show the search results with a quick tip, but the panel
      # itself is not technically "visible" in CSS terms.
      def has_search_menu?
        page.has_css?(".search-menu .search-menu-panel", visible: false)
      end

      def has_no_search_menu_visible?
        page.has_no_css?(".search-menu .search-menu-panel")
      end

      SEARCH_ICON_SELECTOR = "#search-button.btn-icon"
      SEARCH_FIELD_SELECTOR = ".floating-search-input .search-menu"
      SEARCH_RESULT_SELECTOR = ".search-results .fps-result"

      def has_search_icon?
        page.has_selector?(SEARCH_ICON_SELECTOR, visible: true)
      end

      def has_no_search_icon?
        page.has_no_selector?(SEARCH_ICON_SELECTOR)
      end

      def has_search_field?
        page.has_selector?(SEARCH_FIELD_SELECTOR, visible: true)
      end

      def has_no_search_field?
        page.has_no_selector?(SEARCH_FIELD_SELECTOR)
      end

      def has_topic_title_for_first_search_result?(title)
        page.has_css?(".search-menu .results .search-result-topic", text: title)
      end

      def has_search_result?
        page.has_selector?(SEARCH_RESULT_SELECTOR)
      end

      def has_no_search_result?
        page.has_no_selector?(SEARCH_RESULT_SELECTOR)
      end

      def has_warning_message?
        page.has_selector?(".search-results .warning")
      end

      def has_found_no_results?
        page.has_css?(".search-menu-container .results .no-results")
      end

      def search_term(id = "icon-search-input")
        page.find("##{id}").value
      end

      SEARCH_PAGE_SELECTOR = "body.search-page"

      def active?
        has_css?(SEARCH_PAGE_SELECTOR)
      end

      def not_active?
        has_no_css?(SEARCH_PAGE_SELECTOR)
      end

      def browser_search_shortcut
        page.send_keys([PLATFORM_KEY_MODIFIER, "f"])
      end
    end
  end
end
