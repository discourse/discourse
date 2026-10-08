# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ReviewableDeleted
      class V1 < ReviewableStatusChanged::V1
        description ReviewableStatusChanged::V1.description_for_status("deleted")
      end
    end
  end
end
