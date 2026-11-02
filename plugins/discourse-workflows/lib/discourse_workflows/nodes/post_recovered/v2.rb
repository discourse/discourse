# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostRecovered
      class V2 < V1
        include PostLifecycle::V2

        description(
          superclass.description.merge(
            version: "2.0",
            output_contracts: PostLifecycle::V2::OUTPUT_CONTRACTS,
          ),
        )
      end
    end
  end
end
