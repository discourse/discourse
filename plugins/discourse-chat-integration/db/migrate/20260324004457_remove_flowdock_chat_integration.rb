# frozen_string_literal: true
class RemoveFlowdockChatIntegration < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM site_settings WHERE name = 'chat_integration_flowdock_enabled';
      DELETE FROM site_settings WHERE name = 'chat_integration_flowdock_excerpt_length';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
