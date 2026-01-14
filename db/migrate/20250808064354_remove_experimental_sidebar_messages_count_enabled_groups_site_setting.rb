# frozen_string_literal: true
class RemoveExperimentalSidebarMessagesCountEnabledGroupsSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'experimental_sidebar_messages_count_enabled_groups'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
