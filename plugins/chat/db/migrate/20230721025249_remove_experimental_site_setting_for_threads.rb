# frozen_string_literal: true

class RemoveExperimentalSiteSettingForThreads < ActiveRecord::Migration[7.0]
  def up
    execute "DELETE FROM site_settings WHERE name='enable_experimental_chat_threaded_discussions'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
