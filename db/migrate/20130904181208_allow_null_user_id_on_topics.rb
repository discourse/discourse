# frozen_string_literal: true

class AllowNullUserIdOnTopics < ActiveRecord::Migration[4.2]
  def up
    change_column :topics, :user_id, :integer, null: true
  end

  def down
    change_column :topics, :user_id, :integer, null: false
  end
end
