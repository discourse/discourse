# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTags
      class V1 < NodeType
        simulation { supported "add", "remove" }

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
            **actor_property,
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |item, item_index|
              operation = exec_ctx.get_node_parameter("operation", item_index, default: "add")
              config = resolve_config(exec_ctx, item:, item_index:, operation:)
              wrap(process(exec_ctx, config.merge("operation" => operation), item_index))
            end

          [items]
        end

        def resolve_config(exec_ctx, item:, item_index:, operation:)
          {
            "topic_id" => exec_ctx.get_node_parameter("topic_id", item_index),
            "tag_names" => exec_ctx.get_node_parameter("tag_names", item_index),
          }
        end

        def simulate_item(exec_ctx, dispatch)
          config = dispatch.config
          topic, actor, names = prepare_tagging(exec_ctx, config, dispatch.item_index)
          actor.guardian.ensure_can_edit_tags!(topic)
          old_tag_names = topic.tags.pluck(:name)

          result =
            if dispatch.operation == "remove"
              { tag_names: old_tag_names & names, topic_id: topic.id }
            else
              { tag_names: names, topic_id: topic.id }
            end
          exec_ctx.record_effect(
            :topic_tagged,
            { topic_id: topic.id, tags: result[:tag_names] },
            item_index: dispatch.item_index,
            touches: [[:topic, topic.id]],
          )

          wrap(result)
        end

        private

        def prepare_tagging(exec_ctx, config, item_index)
          topic =
            exec_ctx.read_record(:topic, config["topic_id"]) ||
              raise(
                ActiveRecord::RecordNotFound,
                "Couldn't find Topic with 'id'=#{config["topic_id"]}",
              )
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)

          names = normalize_tag_names(config["tag_names"])
          if names.empty?
            raise_node_error!(I18n.t("discourse_workflows.errors.topic_tags.no_tag_names"))
          end
          ensure_can_tag_personal_message!(topic, actor)
          [topic, actor, names]
        end

        def process(exec_ctx, config, item_index)
          topic, actor, names = prepare_tagging(exec_ctx, config, item_index)
          guardian = actor.guardian

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

        def ensure_can_tag_personal_message!(topic, actor)
          guardian = actor.guardian
          return if !topic.private_message? || guardian.can_tag_pms?
          return if !SiteSetting.tagging_enabled || !guardian.authenticated?

          raise_node_error!(
            I18n.t(
              "discourse_workflows.errors.topic_tags.personal_message_not_allowed",
              username: actor.username,
            ),
          )
        end

        def tag_topic!(topic, guardian, tag_names, append: false, &)
          guardian.ensure_can_edit_tags!(topic)

          unless DiscourseTagging.tag_topic_by_names(topic, guardian, tag_names, append:, &)
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
