# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTimerSet
      class V1 < TopicTimerChanged::V1
        description(TopicTimerChanged::V1.description_for_change("set"))
      end
    end
  end
end
