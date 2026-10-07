# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicUnarchived
      class V1 < TopicStatusChanged::V1
        description TopicStatusChanged::V1.description_for_change("unarchived")
      end
    end
  end
end
