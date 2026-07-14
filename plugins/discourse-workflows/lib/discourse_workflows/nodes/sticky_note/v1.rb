# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module StickyNote
      class V1 < NodeType
        description(
          name: "flow:sticky_note",
          version: "1.0",
          defaults: {
            icon: "note-sticky",
            color: "yellow",
          },
          palette_visible: false,
          inputs: [],
          outputs: [],
          properties: {
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
          },
        )

        def execute(exec_ctx)
          [exec_ctx.input_items]
        end
      end
    end
  end
end
