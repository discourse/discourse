# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ReviewableCreated
      class V1 < NodeType
        description(
          name: "trigger:reviewable_created",
          version: "1.0",
          defaults: {
            icon: "flag",
            color: "orange",
          },
          group: "discourse_triggers",
          event: :reviewable_created,
          output_contracts: [{ schema: Schema::REVIEWABLE_EVENT_SCHEMA }],
          properties: REVIEWABLE_TYPE_FILTER_PROPERTIES,
        )

        def self.load_options_context(context)
          load_reviewable_type_options(context)
        end

        def initialize(reviewable, *)
          super(parameters: {})
          @reviewable = reviewable
        end

        def valid?
          @reviewable.present?
        end

        def output
          { reviewable: serialize_reviewable(@reviewable) }
        end

        def matches?(trigger_ctx)
          matches_reviewable_types?(@reviewable, trigger_ctx.get_node_parameter("reviewable_types"))
        end
      end
    end
  end
end
