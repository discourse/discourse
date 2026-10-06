# frozen_string_literal: true

class CreateKanbanCardHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_kanban_card_histories do |t|
      t.bigint :acting_user_id, null: false
      t.integer :action, null: false
      t.bigint :board_id, null: false
      t.bigint :card_id, null: false
      t.jsonb :details
      t.timestamps
    end

    add_index :discourse_kanban_card_histories, :acting_user_id
    add_index :discourse_kanban_card_histories, %i[board_id card_id]
    add_index :discourse_kanban_card_histories,
              "board_id, card_id, acting_user_id, (created_at::date)",
              unique: true,
              where: "action = 7", # card_viewed
              name: "index_discourse_kanban_card_histories_one_view_per_user_day"
  end
end
