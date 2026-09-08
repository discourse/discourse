# frozen_string_literal: true

module Boards
  class MoveColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :column_id, :integer
      attribute :direction, :integer
      attribute :client_id, :string

      validates :board_id, presence: true
      validates :column_id, presence: true
      validates :direction, presence: true, inclusion: { in: [-1, 1] }
    end

    model :board
    policy :can_manage
    model :column

    transaction { step :swap_positions }

    step :publish_reorder

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_manage(guardian:, board:)
      guardian.can_manage_boards_board?(board)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.column_id)
    end

    def swap_positions(board:, column:, params:)
      ordered = board.columns.order(:position, :id).lock("FOR UPDATE").to_a
      current_index = ordered.index(column)
      new_index = current_index + params.direction

      if new_index < 0 || new_index >= ordered.length
        fail!(I18n.t("boards.errors.column_move_out_of_bounds"))
      end

      neighbor = ordered[new_index]
      column.position, neighbor.position = neighbor.position, column.position
      column.save!
      neighbor.save!

      context[:column_order] = board.columns.order(:position, :id).pluck(:id)
    end

    def publish_reorder(board:, params:)
      Publisher.publish_columns_reordered!(
        board,
        context[:column_order],
        client_id: params.client_id,
      )
    end
  end
end
