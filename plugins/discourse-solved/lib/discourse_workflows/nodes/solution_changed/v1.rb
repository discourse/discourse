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
              DiscourseWorkflows::Schema::POST_AUTHOR_SCHEMA,
              DiscourseWorkflows::Schema::ACTOR_SCHEMA,
            ).freeze

          description(
            name: "trigger:solution_changed",
            version: "1.0",
            defaults: {
              icon: "square-check",
              color: "green",
            },
            group: "discourse_triggers",
            palette_visible: false,
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
              **TOPIC_SCOPE_FILTER_PROPERTIES,
            },
          )

          CHANGE_OUTPUT_SCHEMA =
            DiscourseWorkflows::Schema.merge(
              DiscourseWorkflows::Schema::POST_SCHEMA,
              DiscourseWorkflows::Schema::TOPIC_LIST_ITEM_SCHEMA,
              DiscourseWorkflows::Schema::POST_AUTHOR_SCHEMA,
              DiscourseWorkflows::Schema::ACTOR_SCHEMA,
            ).freeze

          def self.description_for_change(name, change)
            description.merge(
              name:,
              palette_visible: true,
              event: CHANGES.key(change),
              fixed_changes: [change],
              i18n_scope: "solution_changed",
              output_contracts: [{ schema: CHANGE_OUTPUT_SCHEMA }],
              properties: properties.except(:changes),
            )
          end

          def self.from_event(event_name, *args)
            new(event_name, *args)
          end

          def initialize(event_name, post, payload = {})
            super(parameters: {})
            @change = CHANGES[event_name]
            @post = post
            @actor = payload[:acting_user]
          end

          def valid?
            fixed_changes = self.class.description[:fixed_changes]
            @change.present? && @post.present? && topic.present? &&
              (fixed_changes.nil? || fixed_changes.include?(@change))
          end

          def output
            {
              **(self.class.description[:fixed_changes] ? {} : { change: @change }),
              post: serialize_post(@post),
              topic: serialize_topic_list_item(topic),
              user: serialize_user(@post.user),
              actor: serialize_user(@actor),
            }
          end

          def matches?(trigger_ctx)
            matches_changes?(trigger_ctx, @change) && matches_topic_filters?(topic, trigger_ctx)
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
