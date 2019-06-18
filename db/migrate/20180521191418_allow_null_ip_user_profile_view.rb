# frozen_string_literal: true

class AllowNullIpUserProfileView < ActiveRecord::Migration[5.1]
  def up
    begin
      Migration::SafeMigrate.disable!
      change_column :user_profile_views, :ip_address, :inet, null: true
    ensure
      Migration::SafeMigrate.enable!
    end

    remove_index :user_profile_views,
      column: [:viewed_at, :ip_address, :user_profile_id],
      name: :unique_profile_view_ip,
      unique: true
    remove_index :user_profile_views,
      column: [:viewed_at, :user_id, :user_profile_id],
      name: :unique_profile_view_user,
      unique: true
    add_index :user_profile_views, [:viewed_at, :user_id, :ip_address, :user_profile_id],
      name: :unique_profile_view_user_or_ip,
      unique: true
  end

  def down
  end
end
