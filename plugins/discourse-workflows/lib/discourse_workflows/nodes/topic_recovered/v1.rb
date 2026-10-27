# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicRecovered
      class V1 < NodeType
        include TopicDeletionTrigger

        description(
          TopicDeletionTrigger.description(
            name: "trigger:topic_recovered",
            event: :topic_recovered,
            icon: "arrow-rotate-right",
            color: "green",
          ),
        )

        # PostDestroyer also fires the event, with `from_trash: false`, when authors cancel their
        # own pending deletion. Topic deleted never fired for that topic, so only Topic#recover! counts.
        def initialize(topic, payload = {})
          super
          @from_trash = payload.fetch(:from_trash, true)
        end

        def valid?
          super && @from_trash
        end
      end
    end
  end
end
