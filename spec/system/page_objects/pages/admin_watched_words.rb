# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWatchedWords < PageObjects::Pages::Base
      def visit(action: "block")
        browser_page
          .goto("admin/customize/watched_words/action/#{action}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def add_word(word)
        ww = browser_root.locator("#watched-words").filter(visible: true)
        ww.locator("#watched-words-header").filter(visible: true).click
        ww.locator(".filter-input").filter(visible: true).press_sequentially(word)
        ww.locator(".select-kit-row").filter(visible: true).click

        browser_root.locator(".watched-words-detail .btn-primary").filter(visible: true).click
      end

      def has_word?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".watched-words-detail .show-words-checkbox").filter(visible: true),
        )
      end

      def add_word_with_tag(word, tag_name)
        words_selector = PageObjects::Components::SelectKit.new("#watched-words")
        words_selector.expand
        words_selector.search(word)
        words_selector.select_row_by_name(word)
        words_selector.collapse

        tag_chooser = PageObjects::Components::SelectKit.new(".tag-chooser")
        tag_chooser.expand
        tag_chooser.search(tag_name)
        tag_chooser.select_row_by_name(tag_name)

        browser_root.locator(".watched-words-detail .btn-primary").filter(visible: true).click
      end

      def has_error?(error)
        PlaywrightMatchers.contain_text([browser_text_pattern(error)], useInnerText: true).matches?(
          browser_root.locator(".dialog-container .dialog-body").filter(visible: true),
        )
      end
    end
  end
end
