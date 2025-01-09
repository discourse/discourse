# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminApiKeys < PageObjects::Pages::Base
      def visit_page
        page.visit "/admin/api/keys"
        self
      end

      def has_api_key_listed?(name)
        page.has_css?(table_selector, text: name)
      end

      def has_revoked_api_key_listed?(name)
        row = page.find(table_selector, text: name)
        row.has_css?(badge_selector, text: I18n.t("admin_js.admin.api_keys.revoked"))
      end

      def has_unrevoked_api_key_listed?(name)
        row = page.find(table_selector, text: name)
        row.has_no_css?(badge_selector, text: I18n.t("admin_js.admin.api_keys.revoked"))
      end

      def has_no_api_key_listed?(name)
        page.has_no_css?(table_selector, text: name)
      end

      def add_api_key(description:)
        page.find(header_actions_selector, text: I18n.t("admin_js.admin.api_keys.add")).click

        form = page.find(".form-kit")
        form.find(description_field_selector).fill_in(with: description)
        form.find(".save").click
      end

      def click_edit(description)
        row = page.find(row_selector, text: description)
        row.find("button", text: I18n.t("admin_js.admin.api_keys.edit")).click
      end

      def click_revoke
        page.find("button", text: I18n.t("admin_js.admin.api_keys.revoke")).click
      end

      def click_unrevoke
        page.find("button", text: I18n.t("admin_js.admin.api_keys.undo_revoke")).click
      end

      def click_delete
        page.find("button", text: I18n.t("admin_js.admin.api_keys.delete")).click
      end

      def edit_description(new_description)
        page.find("button", text: I18n.t("admin_js.admin.api_keys.edit")).click
        page.find(description_field_selector).fill_in(with: new_description)
        page.find("button", text: I18n.t("admin_js.admin.api_keys.save")).click
      end

      def click_back
        page.find("a.back-button").click
      end

      private

      def table_selector
        ".admin-api_keys__items"
      end

      def row_selector
        ".d-admin-row__content"
      end

      def badge_selector
        ".d-admin-table__badge"
      end

      def header_actions_selector
        ".d-page-header__actions"
      end

      def description_field_selector
        "input[name='description']"
      end
    end
  end
end
