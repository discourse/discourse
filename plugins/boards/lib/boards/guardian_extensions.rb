# frozen_string_literal: true

module Boards
  module GuardianExtensions
    def can_manage_boards?
      in_any_groups?(SiteSetting.boards_manage_board_allowed_groups_map)
    end

    def can_create_board?
      can_manage_boards?
    end

    def can_destroy_board?(board)
      !board.archived? && can_manage_boards? && has_acl_permission?(board, "manage")
    end

    def can_manage_board?(board)
      !board.archived? && can_manage_boards? && has_acl_permission?(board, "manage")
    end

    def can_read_board?(board)
      return true if board.anonymous_can_read?

      has_any_acl_permission?(board, %w[view edit manage])
    end

    def can_write_board?(board)
      !board.archived? && has_any_acl_permission?(board, %w[edit manage])
    end

    def can_archive_board?(board)
      authenticated? && !board.archived? && has_acl_permission?(board, "manage")
    end

    def can_unarchive_board?(board)
      authenticated? && board.archived? && has_acl_permission?(board, "manage")
    end

    def can_view_card?(card)
      can_read_board?(card.board)
    end
  end
end
