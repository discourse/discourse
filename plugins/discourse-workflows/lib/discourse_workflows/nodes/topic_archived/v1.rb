# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicArchived
      class V1 < TopicStatusChanged::V1
        description TopicStatusChanged::V1.description_for_change("archived")
      end
    end
  end
end
