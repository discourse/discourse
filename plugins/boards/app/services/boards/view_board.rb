# frozen_string_literal: true

module Boards
  class ViewBoard
    include Service::Base

    params { attribute :id, :integer }

    policy :is_logged_in
    model :board
    policy :can_read_board
    step :create_view_history

    private

    def is_logged_in(guardian:)
      guardian.authenticated?
    end

    def fetch_board(params:)
      Boards::Board.find_by(id: params.id)
    end

    def can_read_board(guardian:, board:)
      guardian.can_read_boards_board?(board)
    end

    def create_view_history(guardian:, board:)
      BoardHistory.create!(
        board:,
        acting_user: guardian.user,
        action: BoardHistory.actions[:board_viewed],
      )
    rescue ActiveRecord::RecordNotUnique
      # We only want to record one view per user per board per day,
      # see the index_discourse_kanban_board_histories_one_view_per_user_day index.
    end
  end
end
