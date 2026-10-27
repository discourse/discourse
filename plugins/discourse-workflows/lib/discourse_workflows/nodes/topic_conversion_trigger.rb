# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicConversionTrigger
      include TopicEventTrigger

      I18N_SCOPE = "topic_conversion_trigger"

      def self.description(name:, event:, icon:, properties: TopicEventTrigger::PROPERTIES)
        TopicEventTrigger.description(
          name:,
          event:,
          icon:,
          color: "light-blue",
          i18n_scope: I18N_SCOPE,
          properties:,
        )
      end
    end
  end
end
