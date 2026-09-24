# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ReviewableStatusChanged
      class V1 < NodeType
        description(
          name: "trigger:reviewable_status_changed",
          version: "1.0",
          defaults: {
            icon: "list-check",
            color: "green",
          },
          group: "discourse_triggers",
          palette_visible: false,
          event: :reviewable_transitioned_to,
          output_contracts: [{ schema: Schema::REVIEWABLE_EVENT_SCHEMA }],
          properties: -> do
            {
              statuses: {
                type: :multi_options,
                default: [],
                options: ::Reviewable.statuses.keys,
              },
              reviewable_types: {
                type: :multi_options,
                options:
                  reviewable_type_options.map do |option|
                    { value: option[:id], label: option[:name] }
                  end,
              },
            }
          end,
        )

        def self.description_for_status(status)
          description.merge(
            name: "trigger:reviewable_#{status}",
            fixed_status: status,
            palette_visible: true,
            i18n_scope: "reviewable_status_changed",
            properties: -> { properties.except(:statuses) },
          )
        end

        def initialize(status, reviewable)
          super(parameters: {})
          @status = status.to_s
          @reviewable = reviewable
        end

        def valid?
          fixed_status = self.class.description[:fixed_status]
          @reviewable.present? && ::Reviewable.statuses.key?(@status) &&
            (fixed_status.nil? || fixed_status == @status)
        end

        def output
          { reviewable: reviewable_data(@reviewable).merge(status: @status) }
        end

        def matches?(trigger_ctx)
          statuses =
            Array.wrap(
              self.class.description[:fixed_status] ||
                trigger_ctx.get_node_parameter("statuses", []),
            ).compact_blank
          return false if statuses.present? && statuses.exclude?(@status)

          matches_reviewable_types?(@reviewable, trigger_ctx.get_node_parameter("reviewable_types"))
        end
      end
    end
  end
end
