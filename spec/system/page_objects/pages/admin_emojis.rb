# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmojis < AdminBase
      def visit_page
        browser_page
          .goto("/admin/config/emoji")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_import_page
        browser_page
          .goto("/admin/config/emoji/import")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_emoji_listed?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
          browser_root.locator(emoji_table_selector).filter(visible: true),
        )
      end

      def has_no_emoji_listed?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).does_not_match?(
          browser_root.locator(emoji_table_selector).filter(visible: true),
        )
      end

      def delete_emoji(name)
        browser_root
          .locator(".d-table__row")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(name))
          .locator(delete_button_selector)
          .filter(visible: true)
          .click
      end

      def upload_zip(path)
        browser_root.locator("input.admin-emoji-import__file-input").set_input_files(path.to_s)
        self
      end

      def has_import_preview?
        have_count(0).does_not_match?(
          browser_root.locator(".admin-emoji-import__summary").filter(visible: true),
        )
      end

      def confirm_import
        browser_root
          .locator(".admin-emoji-import__actions .btn-primary")
          .filter(visible: true)
          .click
        self
      end

      def click_tab(tab_name)
        browser_root.locator(".admin-emoji-tabs__#{tab_name}").filter(visible: true).click
        self
      end

      private

      def emoji_table_selector
        "#custom_emoji"
      end

      def delete_button_selector
        ".d-table__cell-action-delete"
      end
    end
  end
end
