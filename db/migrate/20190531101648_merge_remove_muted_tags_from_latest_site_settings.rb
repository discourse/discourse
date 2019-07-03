# frozen_string_literal: true

class MergeRemoveMutedTagsFromLatestSiteSettings < ActiveRecord::Migration[5.2]
  def up
    execute "UPDATE site_settings SET value = 'always', data_type = 7 WHERE name = 'remove_muted_tags_from_latest' AND value = 't'"
    execute "UPDATE site_settings SET value = 'never',  data_type = 7 WHERE name = 'remove_muted_tags_from_latest' AND value = 'f'"
    execute "DELETE FROM site_settings WHERE name = 'mute_other_present_tags'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
