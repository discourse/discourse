class AddProfileBackgroundToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :profile_background, :string, limit: 255
  end
end
