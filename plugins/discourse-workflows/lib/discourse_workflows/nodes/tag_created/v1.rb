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
          output_contracts: [{ schema: Schema::TAG_SCHEMA }],
        )

        def initialize(tag, *)
          super(parameters: {})
          @tag = tag
        end

        def valid?
          @tag.present?
        end

        def output
          { tag: serialize_record(@tag, TagSerializer) }
        end
      end
    end
  end
end
