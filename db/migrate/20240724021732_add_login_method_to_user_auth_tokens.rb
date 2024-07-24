# frozen_string_literal: true

class AddLoginMethodToUserAuthTokens < ActiveRecord::Migration[7.1]
  def change
    add_column :user_auth_tokens,
               :login_method,
               :string,
               default: Auth::LOGIN_METHOD_LOCAL,
               limit: 5
  end
end
