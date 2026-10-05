# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicUnlisted
      class V1 < TopicStatusChanged::V1
        description TopicStatusChanged::V1.description_for_change("unlisted")
      end
    end
  end
end
