class AddProfileBackgroundToUser < ActiveRecord::Migration
  def change
    add_column :users, :profile_background, :string, limit: 255
  end
end
