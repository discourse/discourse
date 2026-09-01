# frozen_string_literal: true

module Chat
  class SeparateSidebarModeSiteSetting < EnumSiteSetting
    class << self
      def valid_value?(val)
        values.any? { |v| v[:value] == val }
      end

      def values
        @values ||= [
          { name: "admin.site_settings.chat_separate_sidebar_mode.never", value: "never" },
          { name: "admin.site_settings.chat_separate_sidebar_mode.always", value: "always" },
          {
            name: "admin.site_settings.chat_separate_sidebar_mode.fullscreen",
            value: "fullscreen",
          },
        ]
      end

      def translate_names?
        true
      end
    end
  end
end
