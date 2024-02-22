# frozen_string_literal: true

module Chat
  class SeparateSidebarModeSiteSetting < EnumSiteSetting
    def self.valid_value?(val)
      values.any? { |v| v[:value] == val }
    end

    def self.values
      @values ||= [
        { name: "admin.site_settings.chat_separate_sidebar_mode.never", value: "never" },
        { name: "admin.site_settings.chat_separate_sidebar_mode.always", value: "always" },
        { name: "admin.site_settings.chat_separate_sidebar_mode.fullscreen", value: "fullscreen" },
      ]
    end

    def self.translate_names?
      true
    end
  end
end
