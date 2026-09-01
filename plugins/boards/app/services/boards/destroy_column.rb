# frozen_string_literal: true

module Boards
  class DestroyColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :id, :integer
      attribute :client_id, :string

      validates :board_id, presence: true
      validates :id, presence: true
    end

    model :board
    policy :can_manage
    model :column

    transaction do
      step :create_history
      step :destroy_column
    end

    step :publish_update

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_manage(guardian:, board:)
      guardian.can_manage_boards_board?(board)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.id)
    end

    def create_history(board:, column:, guardian:)
      BoardHistory.create!(
        board:,
        column:,
        acting_user: guardian.user,
        action: :column_deleted,
        details: column_details(column),
      )
    end

    def destroy_column(column:)
      ColumnMutator.destroy!(column:)
    end

    def publish_update(board:, params:)
      Publisher.publish_board_updated!(board, client_id: params.client_id)
    end

    def column_details(column)
      { title: column.title }
    end
  end
end
