# frozen_string_literal: true

class AddScopesToUserApiKeys < ActiveRecord::Migration[4.2]
  def change
    add_column :user_api_keys, :scopes, :text, array: true, null: false, default: []

    execute "UPDATE user_api_keys SET scopes = scopes || ARRAY['write'] WHERE write"
    execute "UPDATE user_api_keys SET scopes = scopes || ARRAY['read'] WHERE read"
    execute "UPDATE user_api_keys SET scopes = scopes || ARRAY['push'] WHERE push"

    remove_column :user_api_keys, :read
    remove_column :user_api_keys, :write
    remove_column :user_api_keys, :push
  end
end
