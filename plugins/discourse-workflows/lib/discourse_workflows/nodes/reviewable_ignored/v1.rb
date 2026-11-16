# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ReviewableIgnored
      class V1 < ReviewableStatusChanged::V1
        description ReviewableStatusChanged::V1.description_for_status("ignored")
      end
    end
  end
end
