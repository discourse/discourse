# frozen_string_literal: true

class AddIndexOnUserAuthTokenUser < ActiveRecord::Migration[5.2]
  def change
    add_index :user_auth_tokens, [:user_id]
  end
end
