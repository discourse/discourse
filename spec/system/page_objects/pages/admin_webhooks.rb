# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWebhooks < PageObjects::Pages::Base
      def visit_page
        browser_page
          .goto("/admin/api/web_hooks")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_webhook_listed?(url)
        contain_text([browser_text_pattern(url)], useInnerText: true).matches?(
          browser_root.locator(table_selector).filter(visible: true),
        )
      end

      def has_no_webhook_listed?(url)
        contain_text([browser_text_pattern(url)], useInnerText: true).does_not_match?(
          browser_root.locator(table_selector).filter(visible: true),
        )
      end

      def has_webhook_details?(url)
        contain_text([browser_text_pattern(url)], useInnerText: true).matches?(
          browser_root.locator(summary_selector).filter(visible: true),
        )
      end

      def click_add
        browser_root
          .locator(header_actions_selector)
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.web_hooks.add")))
          .click
        self
      end

      def fill_payload_url(payload_url)
        browser_root
          .locator(form_selector)
          .filter(visible: true)
          .locator(payload_url_field_selector)
          .filter(visible: true)
          .fill(payload_url)
        self
      end

      def add_webhook(payload_url:)
        click_add
        fill_payload_url(payload_url)
        click_save
      end

      def edit_payload_url(payload_url)
        form = browser_root.locator(form_selector).filter(visible: true)
        form.locator(payload_url_field_selector).filter(visible: true).fill(payload_url)

        click_save
      end

      def click_back
        browser_root.locator(back_button_selector).filter(visible: true).click
      end

      def click_save
        browser_root.locator(save_button_selector).filter(visible: true).click
      end

      def click_edit(payload_url)
        row =
          browser_root
            .locator(row_selector)
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(payload_url))
        row
          .locator("button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.web_hooks.edit")))
          .click
      end

      def click_delete(payload_url)
        row =
          browser_root
            .locator(row_selector)
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(payload_url))
        row.locator(".webhook-menu-trigger").filter(visible: true).click
        browser_root.locator(".admin-web-hook__delete").filter(visible: true).click
      end

      private

      def table_selector
        ".admin-web_hooks__items"
      end

      def row_selector
        ".d-table__row"
      end

      def form_selector
        ".form-kit"
      end

      def summary_selector
        ".admin-webhooks__summary"
      end

      def header_actions_selector
        ".d-page-header__actions"
      end

      def payload_url_field_selector
        "input[name='payload_url']"
      end

      def save_button_selector
        ".save"
      end

      def back_button_selector
        ".go-back"
      end
    end
  end
end
