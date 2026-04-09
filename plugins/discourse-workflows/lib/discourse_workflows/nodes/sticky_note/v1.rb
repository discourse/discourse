# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module StickyNote
      class V1 < NodeType
        def self.identifier
          "core:sticky_note"
        end

        def self.icon
          "note-sticky"
        end

        def self.color
          "yellow"
        end

        def self.palette_visible?
          false
        end

        def self.inputs
          []
        end

        def self.outputs
          []
        end

        def self.configuration_schema
          {
            content: {
              type: :string,
              required: false,
            },
            height: {
              type: :integer,
              required: false,
            },
            width: {
              type: :integer,
              required: false,
            },
            color: {
              type: :string,
              required: false,
            },
          }
        end

        def execute(exec_ctx)
          [exec_ctx.input_items]
        end
      end
    end
  end
end
