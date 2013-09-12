class ActingUserNull < ActiveRecord::Migration
  def up
    change_column :user_histories, :acting_user_id, :integer, :null => true
  end

  def down
    execute "DELETE FROM user_histories WHERE acting_user_id IS NULL"
    change_column :user_histories, :acting_user_id, :integer, :null => false
  end
end
