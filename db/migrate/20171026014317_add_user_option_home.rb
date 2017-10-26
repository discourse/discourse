class AddUserOptionHome < ActiveRecord::Migration[5.1]
  def change
    add_column :user_options, :user_home, :integer, null: false, default: 0
  end
end
