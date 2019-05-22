# frozen_string_literal: true

class AddPriorityToPostActionTypes < ActiveRecord::Migration[5.2]
  def up
    add_column :post_action_types, :reviewable_priority, :integer, default: 0, null: false
    execute(<<~SQL)
      UPDATE post_action_types
      SET reviewable_priority = CASE
        WHEN score_bonus > 5 THEN 10
        WHEN score_bonus > 0 THEN 5
        ELSE 0
      END
    SQL
  end

  def down
    remove_column :post_action_types, :reviewable_priority
  end
end
