# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserSearch
      class V1 < NodeType
        description(
          name: "trigger:user_search",
          version: "1.0",
          defaults: {
            icon: "magnifying-glass",
            color: "blue",
          },
          group: "discourse_triggers",
          events: [:user_search],
        )

        def initialize(query, *)
          super(parameters: {})
          @query = query.to_s
        end

        def valid?
          @query.present?
        end

        def output
          { query: @query }
        end
      end
    end
  end
end
