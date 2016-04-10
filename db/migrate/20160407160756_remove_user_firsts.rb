class RemoveUserFirsts < ActiveRecord::Migration
  def up
    drop_table :user_firsts
  end
end
