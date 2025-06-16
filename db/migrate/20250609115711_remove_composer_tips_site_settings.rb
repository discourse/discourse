# frozen_string_literal: true
class RemoveComposerTipsSiteSettings < ActiveRecord::Migration[7.2]
  def up
    execute "DELETE FROM site_settings WHERE name='disable_avatar_education_message'"
    execute "DELETE FROM site_settings WHERE name='sequential_replies_threshold'"
    execute "DELETE FROM site_settings WHERE name='warn_reviving_old_topic_age'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
