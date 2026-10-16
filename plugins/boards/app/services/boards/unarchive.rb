# frozen_string_literal: true

module Boards
  class Unarchive
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :slug, :string
      attribute :client_id, :string

      validates :board_id, presence: true
    end

    try ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique do
      transaction do
        model :board
        policy :can_unarchive
        step :unarchive_board
        step :record_history
      end
    end

    step :publish_board_unarchived_event

    private

    def fetch_board(params:)
      Board.lock.find_by(id: params.board_id)
    end

    def can_unarchive(guardian:, board:)
      guardian.can_unarchive_board?(board)
    end

    def unarchive_board(board:, params:)
      board.update!(
        slug: params.slug.presence || board.original_slug,
        archived: false,
        archived_at: nil,
        archived_by_id: nil,
        original_slug: nil,
      )
    end

    def record_history(board:, guardian:)
      board.history.create!(
        acting_user: guardian.user,
        action: :board_unarchived,
        details: {
          previous_value: board.slug_before_last_save,
          new_value: board.slug,
        },
      )
    end

    def publish_board_unarchived_event(board:, guardian:, params:)
      Boards::Publisher.publish_board_unarchived!(board, client_id: params.client_id)
    end
  end
end
