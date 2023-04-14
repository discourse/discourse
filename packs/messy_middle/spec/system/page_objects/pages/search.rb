# frozen_string_literal: true

module PageObjects
  module Pages
    class Search < PageObjects::Pages::Base
      def type_in_search(input)
        find("input.full-page-search").send_keys(input)
        self
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

      def has_search_result?
        page.has_selector?(".search-results .fps-result")
      end

      def has_warning_message?
        page.has_selector?(".search-results .warning")
      end

      def is_search_page
        has_css?("body.search-page")
      end
    end
  end
end
