# frozen_string_literal: true

module PageObjects
  module Components
    class BookmarkMenu < PageObjects::Components::Base
      def click_menu_option(option_id)
        browser_root
          .locator(".bookmark-menu__row[data-menu-option-id='#{option_id}']")
          .filter(visible: true)
          .click
      end

      def open?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".bookmark-menu-content").filter(visible: true),
        )
      end

      def topic_bookmark_button
        browser_root.locator("#topic-footer-buttons .bookmark-menu__trigger").filter(visible: true)
      end

      def click_topic_bookmark_button
        topic_bookmark_button.click
      end

      def has_topic_bookmark_button_label?(text)
        PlaywrightMatchers.contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator("#topic-footer-buttons .bookmark-menu__trigger").filter(
            visible: true,
          ),
        )
      end

      def has_topic_bookmark_button_title?(title)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#topic-footer-buttons .bookmark-menu__trigger[title='#{title}']",
          ).filter(visible: true),
        )
      end

      def topic_bookmarks_menu_open?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".topic-bookmarks-menu-content").filter(visible: true),
        )
      end

      def has_post_bookmark_option?(post_number)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='post-#{post_number}']",
          ).filter(visible: true),
        )
      end

      def click_post_bookmark(post_number)
        browser_root
          .locator(
            ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='post-#{post_number}'] .bookmark-menu__row-btn",
          )
          .filter(visible: true)
          .click
      end

      def has_post_submenu?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".bookmark-menu__row[data-menu-option-id='jump']").filter(
            visible: true,
          ),
        ) &&
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".bookmark-menu__row[data-menu-option-id='delete']").filter(
              visible: true,
            ),
          )
      end

      def click_post_submenu_option(option_id)
        browser_root
          .locator(".bookmark-menu__row[data-menu-option-id='#{option_id}'] .btn")
          .filter(visible: true)
          .click
      end

      def has_bookmark_topic_option?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='bookmark-topic']",
          ).filter(visible: true),
        )
      end

      def has_clear_all_option?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='clear-all']",
          ).filter(visible: true),
        )
      end

      def has_edit_topic_bookmark_option?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='edit-topic-bookmark']",
          ).filter(visible: true),
        )
      end

      def has_delete_topic_bookmark_option?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".topic-bookmarks-menu-content .bookmark-menu__row[data-menu-option-id='delete-topic-bookmark']",
          ).filter(visible: true),
        )
      end
    end
  end
end
