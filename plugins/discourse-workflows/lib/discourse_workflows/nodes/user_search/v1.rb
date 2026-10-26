# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserSearch
      class V1 < NodeType
        OUTPUT_SCHEMA =
          Schema.merge(
            Schema.document("query" => { "type" => "string" }),
            Schema::ACTOR_SCHEMA,
          ).freeze

        description(
          name: "trigger:user_search",
          version: "1.0",
          defaults: {
            icon: "magnifying-glass",
            color: "blue",
          },
          group: "discourse_triggers",
          event: :user_search,
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
        )

        def initialize(query, payload = {})
          super(parameters: {})
          @query = query.to_s
          @actor = payload[:acting_user]
        end

        def valid?
          @query.present?
        end

        def output
          { query: @query, actor: serialize_user(@actor) }
        end
      end
    end
  end
end
