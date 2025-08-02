# frozen_string_literal: true
#
class RenameRevokeApiKeysSettings < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET name = 'revoke_api_keys_unused_days' where name = 'revoke_api_keys_days'"
    execute "UPDATE site_settings SET name = 'revoke_user_api_keys_unused_days' where name = 'expire_user_api_keys_days'"
  end

  def down
    execute "UPDATE site_settings SET name = 'revoke_api_keys_days' where name = 'revoke_api_keys_unused_days'"
    execute "UPDATE site_settings SET name = 'expire_user_api_keys_days' where name = 'revoke_user_api_keys_unused_days'"
  end
end
