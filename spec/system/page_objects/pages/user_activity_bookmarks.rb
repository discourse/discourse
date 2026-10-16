# frozen_string_literal: true

module PageObjects
  module Pages
    class UserActivityBookmarks < PageObjects::Pages::Base
      def visit(user, q: nil)
        url = "/u/#{user.username_lower}/activity/bookmarks"
        url += "?q=#{q}" if q
        browser_page.goto(url).tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def search_for(query)
        fill_in_search(query).submit_button.click
        self
      end

      def clear_query
        search_for("")
        self
      end

      def clear_query_with_backspace
        search_element.click
        browser_page.evaluate(
          "function(arguments) { arguments[0].selectionStart = arguments[0].selectionEnd = arguments[0].value.length }",
          arg: browser_arguments(search_element),
        )
        search_element.input_value.length.times { browser_page.keyboard.press("Backspace") }
        self
      end

      def fill_in_search(query)
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator(
              "[id=#{"bookmark-search".to_s.to_json}], [name=#{"bookmark-search".to_s.to_json}]",
            ).or(browser_root.get_by_label("bookmark-search", exact: true)),
          )
          .filter(visible: true)
          .fill(query)
        self
      end

      def search_element
        browser_root.locator("#bookmark-search").filter(visible: true)
      end

      def has_empty_search?
        search_element.input_value == ""
      end

      def has_topic?(topic)
        contain_text(browser_text_pattern(topic.title), useInnerText: true).matches?(
          browser_content,
        )
      end

      def has_no_topic?(topic)
        contain_text(browser_text_pattern(topic.title), useInnerText: true).does_not_match?(
          browser_content,
        )
      end

      def bookmark_list
        PageObjects::Components::BookmarkList.new
      end

      def submit_button
        browser_root.locator(".bookmark-search-form button").filter(visible: true)
      end
    end
  end
end
