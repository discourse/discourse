# frozen_string_literal: true

module Chat
  class PreferredIndexSiteSetting < EnumSiteSetting
    def self.valid_value?(value)
      values.any? { |option| option[:value] == value }
    end

    def self.values
      @values ||=
        %w[channels direct_messages my_threads].map do |value|
          { name: "admin.site_settings.chat_preferred_index.#{value}", value: }
        end
    end

    def self.translate_names?
      true
    end
  end
end
