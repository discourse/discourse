# frozen_string_literal: true

module Boards
  class CreateColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :title, :string
      attribute :icon, :string
      attribute :color, :string
      attribute :default_sort, :string
      attribute :tag_name, :string
      attribute :move_to_category_id, :integer
      attribute :move_to_assigned, :string
      attribute :move_to_status, :string
      attribute :client_id, :string

      validates :board_id, presence: true
      validates :title, presence: true
      validates :color, format: { with: /\A(\h{3}|\h{6})\z/ }, allow_nil: true
    end

    model :board
    policy :can_manage

    transaction do
      model :column, :create_column
      step :create_history
    end

    step :publish_update

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_manage(guardian:, board:)
      guardian.can_manage_boards_board?(board)
    end

    def create_column(board:, params:, guardian:)
      position = (board.columns.maximum(:position) || -1) + 1
      ColumnMutator.apply!(
        column: board.columns.build,
        attributes: params.to_hash,
        guardian:,
        position:,
      )
    end

    def create_history(board:, column:, guardian:)
      BoardHistory.create!(
        board:,
        column:,
        acting_user: guardian.user,
        action: :column_added,
        details: column_details(column),
      )
    end

    def publish_update(board:, params:)
      Publisher.publish_board_updated!(board, client_id: params.client_id)
    end

    def column_details(column)
      {
        title: column.title,
        color: column.color,
        tag_id: column.tag_id,
        move_to_category_id: column.move_to_category_id,
        move_to_assigned: column.move_to_assigned,
        move_to_status: column.move_to_status,
      }
    end
  end
end
