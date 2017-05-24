module DiscourseNarrativeBot
  class WelcomePostTypeSiteSetting
    def self.valid_value?(val)
      values.any? { |v| v[:value] == val.to_s }
    end

    def self.values
      @values ||= [
        { name: 'discourse_narrative_bot.welcome_post_type.new_user_track', value: 'new_user_track' },
        { name: 'discourse_narrative_bot.welcome_post_type.welcome_message', value: 'welcome_message' }
      ]
    end

    def self.translate_names?
      true
    end
  end
end
