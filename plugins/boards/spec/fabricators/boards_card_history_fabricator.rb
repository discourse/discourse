# frozen_string_literal: true

Fabricator(:boards_card_history, class_name: "Boards::CardHistory") do
  board { |attrs| attrs[:card]&.board || Fabricate(:boards_board) }
  card { |attrs| Fabricate(:boards_card, board: attrs[:board]) }
  acting_user { Fabricate(:user) }
  action :card_viewed
end
