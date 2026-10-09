# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicPinned
      class V1 < TopicStatusChanged::V1
        description TopicStatusChanged::V1.description_for_change("pinned")
      end
    end
  end
end
