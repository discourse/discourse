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

        def self.color_key
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
              type: :number,
              required: false,
            },
            width: {
              type: :number,
              required: false,
            },
            color: {
              type: :string,
              required: false,
            },
          }
        end

        def execute(_exec_ctx)
          raise "Sticky notes are not executable"
        end
      end
    end
  end
end
