# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTimerCleared
      class V1 < TopicTimerChanged::V1
        description(TopicTimerChanged::V1.description_for_change("cleared"))
      end
    end
  end
end
