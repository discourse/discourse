# frozen_string_literal: true

Fabricator(:boards_column, class_name: "Boards::Column") do
  board { Fabricate(:boards_board) }
  title { Faker::Lorem.words(number: 2).map(&:capitalize).join(" ") }
  position { sequence(:boards_column_position) }
end
