class AddViewsToUserProfile < ActiveRecord::Migration
  def change
    add_column :user_profiles, :views, :integer, default: 0, null: false
  end
end
