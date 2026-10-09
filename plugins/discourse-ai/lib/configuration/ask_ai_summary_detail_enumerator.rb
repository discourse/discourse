# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class AskAiSummaryDetailEnumerator < ::EnumSiteSetting
      def self.valid_value?(value)
        values.any? { |entry| entry[:value] == value }
      end

      def self.values
        @values ||= [
          { name: "admin.site_settings.ai_ask_ai_summary_detail.quiet", value: "quiet" },
          { name: "admin.site_settings.ai_ask_ai_summary_detail.balanced", value: "balanced" },
          { name: "admin.site_settings.ai_ask_ai_summary_detail.detailed", value: "detailed" },
        ]
      end

      def self.translate_names?
        true
      end
    end
  end
end
