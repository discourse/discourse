class CreateUserProfileViews < ActiveRecord::Migration
  def change
    create_table :user_profile_views do |t|
      t.integer :user_profile_id, null: false
      t.datetime :viewed_at, null: false
      t.inet :ip_address, null: false
      t.integer :user_id
    end

    add_index :user_profile_views, :user_profile_id
    add_index :user_profile_views, :user_id
    add_index :user_profile_views, [:viewed_at, :ip_address, :user_profile_id], where: "user_id IS NULL", unique: true, name: 'unique_profile_view_ip'
    add_index :user_profile_views, [:viewed_at, :user_id, :user_profile_id], where: "user_id IS NOT NULL", unique: true, name: 'unique_profile_view_user'
  end
end
