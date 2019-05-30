# frozen_string_literal: true

class AddPathToUserAuthTokenLog < ActiveRecord::Migration[4.2]
  def change
    add_column :user_auth_token_logs, :path, :string
  end
end
