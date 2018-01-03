class AddModeratorToUser < ActiveRecord::Migration[4.2]
  def up
    add_column :users, :moderator, :boolean, default: false
    execute "UPDATE users SET trust_level = 1, moderator = 't' where trust_level = 5"
  end

  def down
    remove_column :users, :moderator
  end
end
