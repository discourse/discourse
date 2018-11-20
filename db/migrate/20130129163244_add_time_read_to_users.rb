class AddTimeReadToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :time_read, :integer, default: 0, null: false

    # Just an estimate
    execute "UPDATE users SET time_read = posts_read_count * 20"
  end
end
