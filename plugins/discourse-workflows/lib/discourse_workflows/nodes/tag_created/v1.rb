# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TagCreated
      class V1 < NodeType
        description(
          name: "trigger:tag_created",
          version: "1.0",
          defaults: {
            icon: "tag",
            color: "deep-orange",
          },
          group: "discourse_triggers",
          event: :tag_created,
          output_contracts: [{ schema: Schema.merge(Schema::TAG_SCHEMA, Schema::ACTOR_SCHEMA) }],
        )

        def initialize(tag, payload = {})
          super(parameters: {})
          @tag = tag
          @actor = payload[:acting_user]
        end

        def valid?
          @tag.present?
        end

        def output
          { tag: serialize_record(@tag, TagSerializer), actor: serialize_user(@actor) }
        end
      end
    end
  end
end
