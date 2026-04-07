# frozen_string_literal: true

module PageObjects
  module Components
    class BookmarkMenu < PageObjects::Components::Base
      def click_menu_option(option_id)
        find(".bookmark-menu__row[data-menu-option-id='#{option_id}']").click
      end

      def open?
        has_css?(".bookmark-menu-content")
      end

      def topic_bookmark_button
        find("#topic-footer-buttons .bookmark-menu__trigger")
      end

      def click_topic_bookmark_button
        topic_bookmark_button.click
      end

      def has_topic_bookmark_button_label?(text)
        has_css?("#topic-footer-buttons .bookmark-menu__trigger", text: text)
      end

      def has_topic_bookmark_button_title?(title)
        has_css?("#topic-footer-buttons .bookmark-menu__trigger[title='#{title}']")
      end

      def topic_bookmarks_menu_open?
        has_css?(".topic-bookmarks-menu-content")
      end

      def has_jump_to_post_option?(post_number)
        has_css?(
          ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='jump']",
          text: "##{post_number}",
        )
      end

      def click_jump_to_post(post_number)
        find(
          ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='jump']",
          text: "##{post_number}",
        ).click
      end

      def has_clear_all_option?
        has_css?(
          ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='clear-all']",
        )
      end

      def has_edit_topic_bookmark_option?
        has_css?(
          ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='edit-topic-bookmark']",
        )
      end

      def has_delete_topic_bookmark_option?
        has_css?(
          ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='delete-topic-bookmark']",
        )
      end
    end
  end
end
