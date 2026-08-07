# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTags
      class V1 < NodeType
        OPERATIONS = %w[add remove].freeze

        description(
          name: "action:topic_tags",
          version: "1.0",
          defaults: {
            icon: "tags",
            color: "orange",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [
            {
              schema: {
                "$schema" => Schema::DRAFT_URI,
                "type" => "object",
                "properties" => {
                  "topic_id" => {
                    "type" => "integer",
                  },
                  "tag_names" => {
                    "type" => "array",
                    "items" => {
                      "type" => "string",
                    },
                  },
                },
              },
            },
          ],
          properties: {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "add",
              ui: {
                expression: true,
              },
            },
            topic_id: {
              type: :string,
              required: true,
            },
            tag_names: {
              type: :string,
              required: false,
              ui: {
                control: :tags,
              },
            },
            actor_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :actor,
              },
            },
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              config = {
                "operation" => exec_ctx.get_node_parameter("operation", item_index, default: "add"),
                "topic_id" => exec_ctx.get_node_parameter("topic_id", item_index),
                "tag_names" => exec_ctx.get_node_parameter("tag_names", item_index),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          topic = ::Topic.find(config["topic_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          guardian = actor.guardian

          names = normalize_tag_names(config["tag_names"])
          if names.empty?
            raise_node_error!(I18n.t("discourse_workflows.errors.topic_tags.no_tag_names"))
          end

          case config["operation"]
          when "remove"
            old_tag_names = topic.tags.pluck(:name)
            desired_tag_names = old_tag_names - names
            tag_topic!(topic, guardian, desired_tag_names)
            { tag_names: old_tag_names & names, topic_id: topic.id }
          else
            tag_topic!(topic, guardian, names, append: true)
            { tag_names: names, topic_id: topic.id }
          end
        end

        def tag_topic!(topic, guardian, tag_names, append: false)
          unless DiscourseTagging.tag_topic_by_names(topic, guardian, tag_names, append:)
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.topic_tags.operation_failed",
                errors: topic.errors.full_messages.join(", "),
              ),
            )
          end
          topic.save!
        end
      end
    end
  end
end
