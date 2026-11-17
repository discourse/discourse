# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTimerCompleted
      class V1 < TopicTimerChanged::V1
        description(TopicTimerChanged::V1.description_for_change("completed"))
      end
    end
  end
end
