# frozen_string_literal: true

module PageObjects
  module Components
    class AdminThemeSettingsEditor < Base
      def fill_in(settings)
        editor.fill_input(settings)
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
