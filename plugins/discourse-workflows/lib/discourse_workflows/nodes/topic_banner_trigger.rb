# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicBannerTrigger
      include TopicEventTrigger

      I18N_SCOPE = "topic_banner_trigger"

      def self.description(name:, event:)
        TopicEventTrigger.description(
          name:,
          event:,
          icon: "bullhorn",
          color: "pink",
          i18n_scope: I18N_SCOPE,
        )
      end
    end
  end
end
