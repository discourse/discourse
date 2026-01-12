# frozen_string_literal: true

module Categories
  module Types
    class Ideas < Base
      class << self
        def available?
          defined?(DiscourseTopicVoting) && SiteSetting.respond_to?(:topic_voting_enabled)
        end

        def enable_plugin
          SiteSetting.topic_voting_enabled = true
        end

        def configure_category(category)
          category.custom_fields[DiscourseTopicVoting::ENABLE_TOPIC_VOTING_SETTING] = true
          category.save_custom_fields
        end

        def icon
          "lightbulb"
        end
      end
    end
  end
end
