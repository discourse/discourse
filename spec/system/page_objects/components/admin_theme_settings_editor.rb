# frozen_string_literal: true

module PageObjects
  module Components
    class AdminThemeSettingsEditor < Base
      def opened?
        expect(browser_root.locator(".ace_editor").filter(visible: true)).not_to have_count(0)
        self
      end

      def set_input(settings)
        editor.set_input(settings)
        self
      end

      def save
        browser_root
          .locator(
            "[id=#{I18n.t("admin_js.admin.customize.theme.save").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.save").to_s.to_json}]",
          )
          .or(
            browser_root.get_by_role("button", name: I18n.t("admin_js.admin.customize.theme.save")),
          )
          .filter(visible: true)
          .click
        self
      end

      private

      def editor
        @editor ||=
          within_browser(browser_root.locator(".settings-editor").filter(visible: true)) do
            AceEditor.new
          end
      end
    end
  end
end
