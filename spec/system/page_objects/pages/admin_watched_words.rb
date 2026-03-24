# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWatchedWords < PageObjects::Pages::Base
      def visit(action: "block")
        page.visit "admin/customize/watched_words/action/#{action}"
        self
      end

      def add_word(word)
        ww = page.find("#watched-words")
        ww.find("#watched-words-header").click
        ww.find(".filter-input").send_keys(word)
        ww.find(".select-kit-row").click

        page.find(".watched-words-detail .btn-primary").click
      end

      def has_word?
        has_css?(".watched-words-detail .show-words-checkbox")
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

        page.find(".watched-words-detail .btn-primary").click
      end

      def has_error?(error)
        has_css?(".dialog-container .dialog-body", text: error)
      end
    end
  end
end
