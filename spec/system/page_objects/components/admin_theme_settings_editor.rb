# frozen_string_literal: true

module PageObjects
  module Components
    class AdminThemeSettingsEditor < Base
      def opened?
        page.has_css?(".cm-editor")
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
        @editor ||= CodeEditor.new(".settings-editor .code-editor")
      end
    end
  end
end
