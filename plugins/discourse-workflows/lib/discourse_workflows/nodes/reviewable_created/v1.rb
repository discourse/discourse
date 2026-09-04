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
          properties: -> do
            {
              reviewable_types: {
                type: :multi_options,
                required: false,
                options:
                  reviewable_type_options.map do |option|
                    { value: option[:id], label: option[:name] }
                  end,
              },
            }
          end,
        )

        class << self
          def load_options_context(context)
            case context.method_name
            when "reviewable_types"
              reviewable_type_options.select { |option| context.matches_filter?(option[:name]) }
            end
          end
        end

        def initialize(reviewable, *)
          super(parameters: {})
          @reviewable = reviewable
        end

        def valid?
          @reviewable.present?
        end

        def output
          { reviewable: reviewable_data(@reviewable) }
        end

        def matches?(trigger_ctx)
          matches_reviewable_types?(@reviewable, trigger_ctx.get_node_parameter("reviewable_types"))
        end
      end
    end
  end
end
