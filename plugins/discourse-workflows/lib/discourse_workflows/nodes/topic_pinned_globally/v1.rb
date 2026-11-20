# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicPinnedGlobally
      class V1 < TopicStatusChanged::V1
        description TopicStatusChanged::V1.description_for_change("pinned_globally")
      end
    end
  end
end
