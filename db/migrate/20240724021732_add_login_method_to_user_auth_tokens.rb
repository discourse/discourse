# frozen_string_literal: true

class AddLoginMethodToUserAuthTokens < ActiveRecord::Migration[7.1]
  def change
    add_column :user_auth_tokens, :authenticated_with_oauth, :boolean, default: false
  end
end
