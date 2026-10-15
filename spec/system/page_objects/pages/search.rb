# frozen_string_literal: true

module PageObjects
  module Pages
    class Search < PageObjects::Pages::Base
      def type_in_search(input)
        filter = browser_root.locator("input.full-page-search").filter(visible: true)
        filter.click
        filter.press("End")
        filter.press_sequentially(input)
        self
      end

      def type_in_search_menu(input)
        browser_root
          .locator(".search-input--header input")
          .filter(visible: true)
          .press_sequentially(input)
        self
      end

      def sort_order
        PageObjects::Components::SelectKit.new("#search-sort-by")
      end

      def bulk_select_result_and_open_dropdown(topic)
        browser_root.locator(".search-info .bulk-select").filter(visible: true).click
        browser_root
          .locator(".fps-result .fps-topic[data-topic-id='#{topic.id}'] .bulk-select input")
          .filter(visible: true)
          .click
        browser_root
          .locator(".search-info .bulk-select-topics-dropdown-trigger")
          .filter(visible: true)
          .click
      end

      def click_search_menu_link
        browser_root.locator(".search-menu .results .search-link").filter(visible: true).click
      end

      def clear_search_input
        browser_root.locator("input.full-page-search").filter(visible: true).fill("")
        self
      end

      def search_input
        browser_root.locator("input.full-page-search").filter(visible: true)
      end

      def has_result_count?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#search-result-count").filter(visible: true),
        )
      end

      def has_no_result_count?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#search-result-count").filter(visible: true),
        )
      end

      def click_search_button
        browser_root.locator(".search-cta").filter(visible: true).click
      end

      def expand_dropdown
        if !browser_root.locator(".search-menu .search-menu-panel").filter(visible: true).count != 0
          click_search_icon
        end
        self
      end

      def click_search_icon
        browser_root.locator(".d-header #search-button").filter(visible: true).click
        expect(
          browser_root.locator(is_mobile? ? ".search-container" : ".search-menu-container").filter(
            visible: true,
          ),
        ).not_to PlaywrightMatchers.have_count(0)
        self
      end

      def click_in_posts_by_user
        browser_root
          .locator(".search-menu-container .search-menu-assistant-item")
          .filter(visible: true)
          .click
      end

      def click_first_topic
        browser_root.locator(".topic-list-body tr:first-of-type").filter(visible: true).click
      end

      def has_search_menu_visible?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".search-menu .search-menu-panel").filter(visible: true),
        )
      end

      # This is used for cases like header and welcome banner search,
      # where we show the search results with a quick tip, but the panel
      # itself is not technically "visible" in CSS terms.
      def has_search_menu?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".search-menu .search-menu-panel"),
        )
      end

      def has_no_search_menu_visible?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".search-menu .search-menu-panel").filter(visible: true),
        )
      end

      SEARCH_ICON_SELECTOR = "#search-button.btn-icon"
      SEARCH_FIELD_SELECTOR = ".floating-search-input .search-menu"
      SEARCH_RESULT_SELECTOR = ".search-results .fps-result"

      def has_search_icon?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(SEARCH_ICON_SELECTOR).filter(visible: true),
        )
      end

      def has_no_search_icon?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(SEARCH_ICON_SELECTOR).filter(visible: true),
        )
      end

      def has_search_field?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(SEARCH_FIELD_SELECTOR).filter(visible: true),
        )
      end

      def has_header_search_menu?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{SEARCH_FIELD_SELECTOR} .search-menu-panel"),
        )
      end

      def has_no_search_field?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(SEARCH_FIELD_SELECTOR).filter(visible: true),
        )
      end

      def has_topic_title_for_first_search_result?(title)
        PlaywrightMatchers.contain_text([browser_text_pattern(title)], useInnerText: true).matches?(
          browser_root.locator(".search-menu .results .search-result-topic").filter(visible: true),
        )
      end

      def has_search_result?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(SEARCH_RESULT_SELECTOR).filter(visible: true),
        )
      end

      def has_no_search_result?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(SEARCH_RESULT_SELECTOR).filter(visible: true),
        )
      end

      def has_warning_message?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".search-results .warning").filter(visible: true),
        )
      end

      def has_found_no_results?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".search-menu-container .results .no-results").filter(visible: true),
        )
      end

      def search_term(id = "icon-search-input")
        browser_root.locator("##{id}").filter(visible: true).input_value
      end

      SEARCH_PAGE_SELECTOR = "body.search-page"

      def active?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(SEARCH_PAGE_SELECTOR).filter(visible: true),
        )
      end

      def not_active?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(SEARCH_PAGE_SELECTOR).filter(visible: true),
        )
      end

      def browser_search_shortcut
        browser_page.keyboard.press(
          [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "f"].join("+"),
        )
      end
    end
  end
end
