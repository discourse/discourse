# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWatchedWords < PageObjects::Pages::Base
      def visit(action: "block")
        page.visit "admin/customize/watched_words/action/#{action}"
        self
      end

      def add_word(word)
        enter_word(word)
        submit
      end

      def submit
        page.find(".watched-words-detail .btn-primary").click
      end

      def has_word?
        has_css?(".watched-words-detail .show-words-checkbox")
      end

      def add_word_with_tag(word, tag_name)
        enter_word(word)

        if find(".tag-chooser").matches_css?(".d-select", wait: 0)
          tag_chooser = PageObjects::Components::UiKit::DSelect.at(".tag-chooser")
          tag_chooser.search(tag_name)
          tag_chooser.select_name(tag_name)
          tag_chooser.close
        else
          tag_chooser = PageObjects::Components::SelectKit.new(".tag-chooser")
          tag_chooser.expand
          tag_chooser.search(tag_name)
          tag_chooser.select_row_by_name(tag_name)
        end

        page.find(".watched-words-detail .btn-primary").click
      end

      def has_error?(error)
        has_css?(".dialog-container .dialog-body", text: error)
      end

      # Types a word into the words field and adds it, leaving the field closed.
      def enter_word(word)
        if SiteSetting.enable_new_select_controls
          words = PageObjects::Components::UiKit::DSelect.by_identifier("watched-words")
          words.search(word)
          words.select_name(word)
          words.close
        else
          # TODO (select-kit-replacement-cleanup)
          words = PageObjects::Components::SelectKit.new("#watched-words")
          words.expand
          words.search(word)
          words.select_row_by_name(word)
          words.collapse
        end
      end
    end
  end
end
