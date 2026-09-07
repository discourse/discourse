# frozen_string_literal: true

module Boards
  class DestroyBoard
    include Service::Base

    params do
      attribute :id, :integer
      attribute :client_id, :string

      validates :id, presence: true
    end

    model :board
    policy :can_destroy
    step :publish_update

    transaction do
      step :destroy
      step :create_history
    end

    private

    def fetch_board(params:)
      Board.find_by(id: params.id)
    end

    def can_destroy(guardian:, board:)
      guardian.can_destroy_boards_board?(board)
    end

    def publish_update(board:, params:)
      Publisher.publish_board_updated!(board, client_id: params.client_id)
    end

    def destroy(board:)
      board.destroy!
    end

    def create_history(board:, guardian:)
      BoardHistory.create!(board:, acting_user: guardian.user, action: "board_deleted")
    end
  end
end
