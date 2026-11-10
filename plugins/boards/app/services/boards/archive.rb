# frozen_string_literal: true

module Boards
  class Archive
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :client_id, :string

      validates :board_id, presence: true
    end

    try ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique do
      transaction do
        model :board
        policy :can_archive
        step :archive_board
        step :record_history
      end

      step :publish_board_archived_event
    end

    private

    def fetch_board(params:)
      Board.lock.find_by(id: params.board_id)
    end

    def can_archive(guardian:, board:)
      guardian.can_archive_board?(board)
    end

    def archive_board(board:, guardian:)
      archived_at = Time.current
      board.update!(
        original_slug: board.slug,
        slug: board.archive_slug(archived_at.to_date),
        archived: true,
        archived_at:,
        archived_by: guardian.user,
      )
    end

    def record_history(board:, guardian:)
      board.history.create!(
        acting_user: guardian.user,
        action: :board_archived,
        details: {
          previous_value: board.slug_before_last_save,
          new_value: board.slug,
        },
      )
    end

    def publish_board_archived_event(board:, guardian:, params:)
      Boards::Publisher.publish_board_archived!(board, client_id: params.client_id)
    end
  end
end
