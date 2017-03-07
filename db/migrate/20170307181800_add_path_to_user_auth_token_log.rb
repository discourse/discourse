class AddPathToUserAuthTokenLog < ActiveRecord::Migration
  def change
    add_column :user_auth_token_logs, :path, :string
  end
end
