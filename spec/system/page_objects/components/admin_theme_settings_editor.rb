# frozen_string_literal: true

module PageObjects
  module Components
    class AdminThemeSettingsEditor < Base
      def opened?
        page.has_css?(".ace_editor")
        self
      end

      def set_input(settings)
        editor.set_input(settings)
        self
      end

      def save
        click_button(I18n.t("admin_js.admin.customize.theme.save"))
        self
      end

      private

      def editor
        @editor ||= within(".settings-editor") { AceEditor.new }
      end
    end
  end
end
