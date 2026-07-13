# frozen_string_literal: true

module DiscourseTopicVoting
  module UpcomingChangesConditionalDisplayExtension
    def should_display_enable_topic_voting_badges?
      SiteSetting.topic_voting_enabled
    end
  end
end
