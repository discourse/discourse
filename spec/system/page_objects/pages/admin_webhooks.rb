# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWebhooks < PageObjects::Pages::Base
      def visit_page
        page.visit("/admin/api/web_hooks")
        self
      end

      def has_webhook_listed?(url)
        page.has_css?(table_selector, text: url)
      end

      def has_no_webhook_listed?(url)
        page.has_no_css?(table_selector, text: url)
      end

      def has_webhook_details?(url)
        page.has_css?(summary_selector, text: url)
      end

      def add_webhook(payload_url:)
        page.find(header_actions_selector, text: I18n.t("admin_js.admin.web_hooks.add")).click

        form = page.find("form.web-hook")
        form.find(payload_url_field_selector).fill_in(with: payload_url)

        click_save
      end

      def edit_payload_url(payload_url)
        form = page.find("form.web-hook")
        form.find(payload_url_field_selector).fill_in(with: payload_url)

        click_save
      end

      def click_back
        page.find(back_button_selector).click
      end

      def click_save
        page.find(save_button_selector).click
      end

      def click_edit(payload_url)
        row = page.find(row_selector, text: payload_url)
        row.find("button", text: I18n.t("admin_js.admin.web_hooks.edit")).click
      end

      def click_delete(payload_url)
        row = page.find(row_selector, text: payload_url)
        row.find(".webhook-menu-trigger").click
        page.find(".admin-web-hook__delete").click
      end

      private

      def table_selector
        ".admin-web_hooks__items"
      end

      def row_selector
        ".d-admin-row__content"
      end

      def summary_selector
        ".admin-webhooks__summary"
      end

      def header_actions_selector
        ".d-page-header__actions"
      end

      def payload_url_field_selector
        "input[name='payload-url']"
      end

      def save_button_selector
        ".admin-webhooks__save-button"
      end

      def back_button_selector
        ".go-back"
      end
    end
  end
end
