# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ReviewablePending
      class V1 < ReviewableStatusChanged::V1
        description ReviewableStatusChanged::V1.description_for_status("pending")
      end
    end
  end
end
