# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module GraphDigest
      module_function

      def call(workflow)
        Digest::SHA256.hexdigest(
          JSON.generate(
            {
              name: workflow.name,
              nodes: workflow.nodes || [],
              connections: workflow.connections || {},
              settings: workflow.settings || {},
            },
          ),
        )
      end
    end
  end
end
