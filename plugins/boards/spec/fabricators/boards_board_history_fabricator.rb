# frozen_string_literal: true

Fabricator(:boards_board_history, class_name: "Boards::BoardHistory") do
  board { Fabricate(:boards_board) }
  acting_user { Fabricate(:user) }
  action :board_viewed
end
