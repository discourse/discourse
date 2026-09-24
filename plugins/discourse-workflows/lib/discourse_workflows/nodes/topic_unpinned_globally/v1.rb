# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicUnpinnedGlobally
      class V1 < TopicStatusChanged::V1
        description TopicStatusChanged::V1.description_for_change("unpinned_globally")
      end
    end
  end
end
