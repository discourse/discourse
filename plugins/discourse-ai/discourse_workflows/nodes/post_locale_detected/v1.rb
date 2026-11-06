# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module PostLocaleDetected
        class V1 < DiscourseWorkflows::NodeType
          include PostLifecycle

          description(
            name: "trigger:post_locale_detected",
            version: "1.0",
            defaults: {
              icon: "language",
              color: "violet",
            },
            group: "discourse_triggers",
            event: :post_locale_detected,
            available: -> { DiscourseAi::Translation.enabled? },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_ai_translation",
            i18n_scope: PostLifecycle::I18N_SCOPE,
            output_contracts: [
              {
                schema:
                  Schema.merge(
                    Schema::POST_SCHEMA,
                    Schema::TOPIC_LIST_ITEM_SCHEMA,
                    Schema::POST_AUTHOR_SCHEMA,
                  ),
              },
            ],
            properties: PostLifecycle::PROPERTIES,
          )

          def output
            {
              post: serialize_post(@post),
              topic: serialize_topic_list_item(topic),
              user: serialize_user(@post.user),
            }
          end
        end
      end
    end
  end
end
