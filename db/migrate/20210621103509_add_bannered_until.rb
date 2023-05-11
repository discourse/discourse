# frozen_string_literal: true

class AddBanneredUntil < ActiveRecord::Migration[6.1]
  def change
    add_column :topics, :bannered_until, :datetime, null: true

    add_index :topics, :bannered_until, where: "bannered_until IS NOT NULL"
  end
end
