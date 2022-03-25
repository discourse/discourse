# frozen_string_literal: true

class CleanUpForeignKeys < ActiveRecord::Migration[6.1]
  def change
    remove_foreign_key(:user_security_keys, :users) if foreign_key_exists?(:user_security_keys, :users)
    remove_foreign_key(:javascript_caches, :themes) if foreign_key_exists?(:javascript_caches, :themes)
    remove_foreign_key(:javascript_caches, :theme_fields) if foreign_key_exists?(:javascript_caches, :theme_fields)
    remove_foreign_key(:user_profiles, column: :granted_title_badge_id) if foreign_key_exists?(:user_profiles, column: :granted_title_badge_id)
    remove_foreign_key(:user_profiles, column: :card_background_upload_id) if foreign_key_exists?(:user_profiles, column: :card_background_upload_id)
    remove_foreign_key(:user_profiles, column: :profile_background_upload_id) if foreign_key_exists?(:user_profiles, column: :profile_background_upload_id)
  end
end
