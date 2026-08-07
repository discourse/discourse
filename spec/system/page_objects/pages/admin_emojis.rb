# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmojis < AdminBase
      def visit_page
        page.visit "/admin/config/emoji"
        self
      end

      def visit_import_page
        page.visit "/admin/config/emoji/import"
        self
      end

      def has_emoji_listed?(name)
        page.has_css?(emoji_table_selector, text: name)
      end

      def has_no_emoji_listed?(name)
        page.has_no_css?(emoji_table_selector, text: name)
      end

      def delete_emoji(name)
        find(".d-table__row", text: name).find(delete_button_selector).click
      end

      def upload_zip(path)
        attach_file(path, class: "admin-emoji-import__file-input", make_visible: true)
        self
      end

      def has_import_preview?
        page.has_css?(".admin-emoji-import__summary")
      end

      def confirm_import
        find(".admin-emoji-import__actions .btn-primary").click
        self
      end

      def click_tab(tab_name)
        find(".admin-emoji-tabs__#{tab_name}").click
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
