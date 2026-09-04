# frozen_string_literal: true

module Boards
  module GuardianExtensions
    def can_manage_boards?
      in_any_groups?(SiteSetting.boards_manage_board_allowed_groups_map)
    end

    def can_create_boards_board?
      can_manage_boards?
    end

    def can_destroy_boards_board?(board)
      can_manage_boards? && has_acl_permission?(board, "manage")
    end

    def can_manage_boards_board?(board)
      can_manage_boards? && has_acl_permission?(board, "manage")
    end

    def can_read_boards_board?(board)
      return true if board.anonymous_can_read?
      return true if can_write_boards_board?(board)

      has_acl_permission?(board, "view")
    end

    def can_write_boards_board?(board)
      has_any_acl_permission?(board, %w[edit manage])
    end

    def can_view_boards_card?(card)
      can_read_boards_board?(card.board)
    end
  end
end
