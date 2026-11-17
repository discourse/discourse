# frozen_string_literal: true
class AddAdminManagedToMcpOauthClients < ActiveRecord::Migration[8.1]
  def change
    add_column :mcp_oauth_clients, :admin_managed, :boolean, default: false, null: false

    up_only { execute <<~SQL }
        UPDATE mcp_oauth_clients
        SET admin_managed = TRUE
        WHERE registration_type = 'pre_registered'
      SQL
  end
end
