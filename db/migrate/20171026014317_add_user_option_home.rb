class AddUserOptionHome < ActiveRecord::Migration[5.1]
  def change
    add_column :user_options, :homepage_id, :integer, null: true, default: nil
  end
end
