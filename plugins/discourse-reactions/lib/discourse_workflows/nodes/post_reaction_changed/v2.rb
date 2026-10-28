# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module PostReactionChanged
        class V2 < V1
          V2_OUTPUT_SCHEMA =
            Schema.merge(OUTPUT_SCHEMA, Schema::POST_AUTHOR_SCHEMA, Schema::ACTOR_SCHEMA).freeze

          CHANGE_OUTPUT_SCHEMA =
            Schema.merge(
              Schema::POST_SCHEMA,
              Schema::TOPIC_LIST_ITEM_SCHEMA,
              Schema::POST_AUTHOR_SCHEMA,
              Schema::ACTOR_SCHEMA,
              Schema.document(
                OUTPUT_SCHEMA.fetch("properties").slice("reaction", "previous_reaction"),
              ),
            ).freeze

          description(
            superclass.description.merge(
              version: "2.0",
              palette_visible: false,
              output_contracts: [{ schema: V2_OUTPUT_SCHEMA }],
            ),
          )

          def self.description_for_change(name, change)
            description.merge(
              name:,
              version: "1.0",
              palette_visible: true,
              fixed_changes: [change],
              i18n_scope: "post_reaction_changed",
              output_contracts: [{ schema: CHANGE_OUTPUT_SCHEMA }],
              properties: properties.except(:changes),
            )
          end

          def valid?
            fixed_changes = self.class.description[:fixed_changes]
            super && (fixed_changes.nil? || fixed_changes.include?(change))
          end

          def output
            data =
              super.then { |data| data.merge(user: serialize_user(@post.user), actor: data[:user]) }
            self.class.description[:fixed_changes] ? data.except(:change) : data
          end
        end
      end
    end
  end
end
