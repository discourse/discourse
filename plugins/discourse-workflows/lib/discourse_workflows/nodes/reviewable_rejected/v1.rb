# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ReviewableRejected
      class V1 < ReviewableStatusChanged::V1
        description ReviewableStatusChanged::V1.description_for_status("rejected")
      end
    end
  end
end
