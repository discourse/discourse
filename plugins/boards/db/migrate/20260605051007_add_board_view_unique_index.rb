# frozen_string_literal: true
class AddBoardViewUniqueIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :discourse_kanban_board_histories,
              "board_id, acting_user_id, (created_at::date)",
              unique: true,
              where: "action = 7", # board_viewed
              name: "index_discourse_kanban_board_histories_one_view_per_user_day"
  end
end
