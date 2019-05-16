# frozen_string_literal: true

class ActingUserNull < ActiveRecord::Migration[4.2]
  def up
    change_column :user_histories, :acting_user_id, :integer, null: true
  end

  def down
    execute "DELETE FROM user_histories WHERE acting_user_id IS NULL"
    change_column :user_histories, :acting_user_id, :integer, null: false
  end
end
