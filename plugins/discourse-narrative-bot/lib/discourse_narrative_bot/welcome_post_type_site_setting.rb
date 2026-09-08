# frozen_string_literal: true

module DiscourseNarrativeBot
  class WelcomePostTypeSiteSetting
    class << self
      def valid_value?(val)
        values.any? { |v| v[:value] == val.to_s }
      end

      def values
        @values ||= [
          {
            name: "discourse_narrative_bot.welcome_post_type.new_user_track",
            value: "new_user_track",
          },
          {
            name: "discourse_narrative_bot.welcome_post_type.welcome_message",
            value: "welcome_message",
          },
        ]
      end

      def translate_names?
        true
      end
    end
  end
end
