# frozen_string_literal: true

module PageObjects
  module Pages
    class Search < PageObjects::Pages::Base
      def type_in_search(input)
        find("input.full-page-search").send_keys(input)
        self
      end

      def type_in_search_menu(input)
        find("input#search-term").send_keys(input)
        self
      end

      def click_search_menu_link
        find(".search-menu .results .search-link").click
      end

      def clear_search_input
        find("input.full-page-search").set("")
        self
      end

      def heading_text
        find("h1.search-page-heading").text
      end

      def click_search_button
        find(".search-cta").click
      end

      def click_home_logo
        find(".d-header .logo-mobile").click
      end

      def click_search_icon
        find(".d-header #search-button").click
      end

      def click_in_posts_by_user
        find(".search-menu-container .search-menu-assistant-item").click
      end

      def click_first_topic
        find(".topic-list-body tr:first-of-type").click
      end

      def has_search_menu_visible?
        page.has_selector?(".search-menu .search-menu-panel", visible: true)
      end

      def has_no_search_menu_visible?
        page.has_no_selector?(".search-menu .search-menu-panel")
      end

      SEARCH_RESULT_SELECTOR = ".search-results .fps-result"

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

      def search_term
        page.find("#search-term").value
      end

      SEARCH_PAGE_SELECTOR = "body.search-page"

      def active?
        has_css?(SEARCH_PAGE_SELECTOR)
      end

      def not_active?
        has_no_css?(SEARCH_PAGE_SELECTOR)
      end
    end
  end
end
