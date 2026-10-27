# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicSlowModeTrigger
      include TopicEventTrigger

      I18N_SCOPE = "topic_slow_mode_trigger"

      def self.description(name:, event:, icon:, output: {})
        TopicEventTrigger.description(
          name:,
          event:,
          icon:,
          color: "light-blue",
          i18n_scope: I18N_SCOPE,
          schema: Schema.merge(TopicEventTrigger::OUTPUT_SCHEMA, Schema.document(output)),
        )
      end
    end
  end
end
