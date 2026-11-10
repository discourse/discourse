# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicListed
      class V1 < TopicStatusChanged::V1
        description TopicStatusChanged::V1.description_for_change("listed")
      end
    end
  end
end
