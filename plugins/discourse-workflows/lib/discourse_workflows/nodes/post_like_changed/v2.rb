# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostLikeChanged
      class V2 < V1
        CHANGE_OUTPUT_SCHEMA =
          Schema.merge(
            Schema::POST_SCHEMA,
            Schema::TOPIC_LIST_ITEM_SCHEMA,
            Schema::POST_AUTHOR_SCHEMA,
            Schema::ACTOR_SCHEMA,
          ).freeze

        description(
          superclass.description.merge(
            version: "2.0",
            palette_visible: false,
            output_contracts: [{ schema: Schema.merge(OUTPUT_SCHEMA, Schema::POST_AUTHOR_SCHEMA) }],
          ),
        )

        def self.description_for_change(change)
          description.merge(
            name: "trigger:post_#{change}",
            version: "1.0",
            palette_visible: true,
            event: CHANGES.key(change),
            fixed_changes: [change],
            i18n_scope: "post_like_changed",
            output_contracts: [{ schema: CHANGE_OUTPUT_SCHEMA }],
            properties: properties.except(:changes),
          )
        end

        private

        def subject_user
          @post.user
        end
      end
    end
  end
end
