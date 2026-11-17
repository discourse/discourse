# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Topic
      class V2 < V1
        DELETION_OPERATIONS = %w[delete recover].freeze
        OPERATIONS = (V1::OPERATIONS + DELETION_OPERATIONS).freeze
        TOPIC_ID_OPERATIONS =
          (
            V1.properties[:topic_id].dig(:display_options, :show, :operation) + DELETION_OPERATIONS
          ).freeze

        TOPIC_RESULT_SCHEMA = Schema.merge(TOPIC_SCHEMA, Schema::TOPIC_AUTHOR_SCHEMA)
        DELETION_RESULT_SCHEMA =
          Schema.merge(
            TOPIC_RESULT_SCHEMA,
            Schema.document(
              "changed" => {
                "type" => "boolean",
                "description" =>
                  "False when the topic was already deleted (delete) or not deleted (recover)",
              },
            ),
          )

        description(
          superclass.description.merge(
            version: "2.0",
            output_contracts:
              output_contracts_for(
                TOPIC_RESULT_SCHEMA,
                Schema::POST_SCHEMA,
                extra_variants: [
                  {
                    schema: DELETION_RESULT_SCHEMA,
                    display_options: {
                      show: {
                        operation: DELETION_OPERATIONS,
                      },
                    },
                  },
                ],
              ),
            properties:
              superclass.properties.merge(
                operation: superclass.properties[:operation].merge(options: OPERATIONS),
                topic_id:
                  superclass.properties[:topic_id].merge(
                    display_options: {
                      show: {
                        operation: TOPIC_ID_OPERATIONS,
                      },
                    },
                  ),
              ),
          ),
        )

        private

        def execute_with_config(exec_ctx, config, item_index)
          return super if DELETION_OPERATIONS.exclude?(config["operation"])

          wrap(
            change_deletion(exec_ctx, config, item_index, deleted: config["operation"] == "delete"),
          )
        end

        def change_deletion(exec_ctx, config, item_index, deleted:)
          topic = ::Topic.with_deleted.find(config["topic_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          guardian = actor.guardian
          was_deleted = topic.trashed?

          if was_deleted == deleted
            guardian.ensure_can_see!(topic)
          else
            if deleted
              exec_ctx.destroy_topic(user: actor, topic:)
            else
              exec_ctx.recover_topic(user: actor, topic:)
            end
            topic.reload
          end

          { **serialize_topic_result(topic, guardian), changed: topic.trashed? != was_deleted }
        end

        def serialize_topic_result(topic, guardian, **)
          super.merge(user: serialize_user(topic.user, guardian:))
        end

        def serialize_topic_post(post, guardian)
          serialize_post(post, guardian:, include_cooked: true)
        end
      end
    end
  end
end
