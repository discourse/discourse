# frozen_string_literal: true

module Chat
  class ArchiveDestinationTopicStatusSiteSetting < EnumSiteSetting
    def self.valid_value?(value)
      values.any? { |option| option[:value] == value }
    end

    def self.values
      @values ||=
        %w[archived open closed].map do |value|
          { name: "admin.site_settings.chat_archive_destination_topic_status.#{value}", value: }
        end
    end

    def self.translate_names?
      true
    end
  end
end
