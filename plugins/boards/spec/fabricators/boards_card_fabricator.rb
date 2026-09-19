# frozen_string_literal: true

Fabricator(:boards_card, class_name: "Boards::Card") do
  board { |attrs| attrs[:column]&.board || Fabricate(:boards_board) }
  column { |attrs| Fabricate(:boards_column, board: attrs[:board]) }
  card_type :floater
  title { Faker::Lorem.sentence(word_count: 10) }
  position { sequence(:boards_card_position) }
end

Fabricator(:boards_topic_card, from: :boards_card) do
  card_type :topic
  title nil
  topic { |attrs| Fabricate(:topic) }
end
