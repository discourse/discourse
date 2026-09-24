# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module SolutionChanged
        class V1 < DiscourseWorkflows::NodeType
          CHANGES = { accepted_solution: "accepted", unaccepted_solution: "removed" }.freeze

          OUTPUT_SCHEMA =
            DiscourseWorkflows::Schema.merge(
              DiscourseWorkflows::Schema::POST_SCHEMA,
              DiscourseWorkflows::Schema::TOPIC_LIST_ITEM_SCHEMA,
              DiscourseWorkflows::Schema.document(
                "change" => {
                  "type" => "string",
                  "enum" => CHANGES.values,
                },
              ),
            ).freeze

          description(
            name: "trigger:solution_changed",
            version: "1.0",
            defaults: {
              icon: "square-check",
              color: "green",
            },
            group: "discourse_triggers",
            event: CHANGES.keys,
            available: -> { SiteSetting.solved_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_solved",
            output_contracts: [{ schema: OUTPUT_SCHEMA }],
            properties: {
              changes: {
                type: :multi_options,
                required: false,
                default: [],
                options: CHANGES.values,
              },
              **CATEGORY_FILTER_PROPERTIES,
              **TAG_FILTER_PROPERTIES,
            },
          )

          def self.from_event(event_name, *args)
            new(event_name, *args)
          end

          def initialize(event_name, post, *)
            super(parameters: {})
            @change = CHANGES[event_name]
            @post = post
          end

          def valid?
            @change.present? && @post.present? && topic.present?
          end

          def output
            { change: @change, post: serialize_post(@post), topic: topic_data(topic) }
          end

          def matches?(trigger_ctx)
            changes =
              Array.wrap(trigger_ctx.get_node_parameter("changes", [])).compact_blank.map(&:to_s)
            return false if changes.present? && changes.exclude?(@change)

            matches_topic_filters?(topic, trigger_ctx)
          end

          private

          def topic
            @topic ||=
              @post.association(:topic).target || ::Topic.with_deleted.find_by(id: @post.topic_id)
          end
        end
      end
    end
  end
end
