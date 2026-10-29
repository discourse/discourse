# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicDeletionTrigger
      include TopicEventTrigger

      I18N_SCOPE = "topic_deletion_trigger"

      def self.description(name:, event:, icon:, color:)
        TopicEventTrigger.description(
          name:,
          event:,
          icon:,
          color:,
          i18n_scope: I18N_SCOPE,
          schema: Schema.merge(TopicEventTrigger::OUTPUT_SCHEMA, Schema::TOPIC_AUTHOR_SCHEMA),
        )
      end

      def output
        super.merge(user: serialize_user(@topic.user))
      end
    end
  end
end
