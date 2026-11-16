# frozen_string_literal: true

class Boards::Policy::CanCreateBoard < Service::PolicyBase
  def call
    guardian.can_create_board?
  end

  def reason
    I18n.t("boards.errors.board_create_forbidden")
  end
end
