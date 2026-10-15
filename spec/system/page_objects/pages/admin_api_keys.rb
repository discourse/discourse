# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminApiKeys < PageObjects::Pages::Base
      def visit_page
        browser_page.goto("/admin/api/keys").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_api_key_listed?(name)
        PlaywrightMatchers.contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
          browser_root.locator(table_selector).filter(visible: true),
        )
      end

      def has_revoked_api_key_listed?(name)
        row =
          browser_root
            .locator(table_selector)
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(name))
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("admin_js.admin.api_keys.revoked"))],
          useInnerText: true,
        ).matches?(row.locator(badge_selector).filter(visible: true))
      end

      def has_unrevoked_api_key_listed?(name)
        row =
          browser_root
            .locator(table_selector)
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(name))
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("admin_js.admin.api_keys.revoked"))],
          useInnerText: true,
        ).does_not_match?(
          row
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(badge_selector)
            .filter(visible: true),
        )
      end

      def has_no_api_key_listed?(name)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(name)],
          useInnerText: true,
        ).does_not_match?(browser_root.locator(table_selector).filter(visible: true))
      end

      def has_generated_api_key?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".generated-api-key").filter(visible: true),
        )
      end

      def has_copy_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".generated-api-key__copy-btn").filter(visible: true),
        )
      end

      def click_copy_key
        browser_root.locator(".generated-api-key__copy-btn").filter(visible: true).click
      end

      def add_api_key(description:)
        browser_root
          .locator(header_actions_selector)
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.api_keys.add")))
          .click

        form = browser_root.locator(".form-kit").filter(visible: true)
        form.locator(description_field_selector).filter(visible: true).fill(description)
        form.locator(".save").filter(visible: true).click
      end

      def click_continue
        browser_root
          .locator("button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.api_keys.continue")))
          .click
      end

      def click_edit(description)
        row =
          browser_root
            .locator(row_selector)
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(description))
        row
          .locator("button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.api_keys.edit")))
          .click
      end

      def click_revoke
        browser_root
          .locator("button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.api_keys.revoke")))
          .click
      end

      def click_unrevoke
        browser_root
          .locator("button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.api_keys.undo_revoke")))
          .click
      end

      def click_delete
        browser_root
          .locator("button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.api_keys.delete")))
          .click
      end

      def edit_description(new_description)
        browser_root
          .locator("button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.api_keys.edit")))
          .click
        browser_root.locator(description_field_selector).filter(visible: true).fill(new_description)
        browser_root
          .locator("button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.api_keys.save")))
          .click
      end

      def click_back
        browser_root.locator("a.back-button").filter(visible: true).click
      end

      def has_warning_banner?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".generated-api-key-container .alert.alert-warning").filter(
            visible: true,
          ),
        )
      end

      def has_scopes_displayed?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(scopes_table_selector).filter(visible: true),
        )
      end

      def has_scope?(resource:, action:)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(/#{resource}.*#{action}/i)],
          useInnerText: true,
        ).matches?(browser_root.locator("#{scopes_table_selector} tr").filter(visible: true))
      end

      private

      def table_selector
        ".admin-api_keys__items"
      end

      def row_selector
        ".d-table__row"
      end

      def badge_selector
        ".status-label"
      end

      def header_actions_selector
        ".d-page-header__actions"
      end

      def description_field_selector
        "input[name='description']"
      end

      def scopes_table_selector
        ".scopes-table"
      end
    end
  end
end
