# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module CardMoved
        class V1 < DiscourseWorkflows::NodeType
          description(
            name: "trigger:card_moved",
            version: "1.0",
            defaults: {
              icon: "arrow-right",
              color: "light-green",
            },
            group: "discourse_triggers",
            event: :boards_card_moved,
            available: -> { SiteSetting.boards_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_boards",
            output_contracts: [{ schema: BoardsSchema::CARD_MOVED_OUTPUT_SCHEMA }],
            capabilities: {
              provides_current_user: true,
            },
            properties: {
              board_id: {
                type: :integer,
                required: false,
                type_options: {
                  load_options_method: "boards",
                },
                no_data_expression: true,
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  filterable: true,
                  value_property: :id,
                  name_property: :name,
                  none: "discourse_workflows.card_moved.board_id_placeholder",
                },
              },
            },
          )

          def initialize(board, card_payload, acting_user, *)
            super(parameters: {})
            card_payload = card_payload.with_indifferent_access
            @card = board.cards.find(card_payload[:id])
            @old_column = board.columns.find_by(id: card_payload[:old_column_id])
            @new_column = board.columns.find(card_payload[:column_id])
            @acting_user = acting_user
          end

          def self.load_options_context(context)
            return unless context.method_name == "boards"

            guardian = context.guardian
            return [] unless guardian.can_manage_boards?

            boards = Boards::Board.with_acl_permission(guardian, "manage")
            if context.filter.present?
              boards =
                boards.where(
                  "name ILIKE ?",
                  "%#{ActiveRecord::Base.sanitize_sql_like(context.filter)}%",
                )
            end
            boards
              .order(:name, :id)
              .select(:id, :name)
              .map { |board| { id: board.id, name: board.unicode_name } }
          end

          def matches?(trigger_ctx)
            board_id = trigger_ctx.get_node_parameter("board_id").presence
            board_id.blank? || board_id.to_i == @card.board_id
          end

          def user_id
            @acting_user.id
          end

          def output
            {
              card:
                @card.as_json(
                  only: BoardsSchema::CARD_PROPERTIES.keys - ["unicode_title"],
                  methods: [:unicode_title],
                ),
              card_moved: {
                old_column: column_data(@old_column),
                new_column: column_data(@new_column),
              },
              acting_user: serialize_record(@acting_user, BasicUserSerializer),
            }
          end

          private

          def column_data(column)
            column&.as_json(
              only: BoardsSchema::COLUMN_PROPERTIES.keys - ["unicode_title"],
              methods: [:unicode_title],
            )
          end
        end
      end
    end
  end
end
