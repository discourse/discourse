# frozen_string_literal: true

class RenameSiteSettingDefaultTopics < ActiveRecord::Migration[5.2]
  def up
    execute "UPDATE site_settings SET name = 'reviewable_default_topics' WHERE name = 'flags_default_topics'"
  end

  def down
    execute "UPDATE site_settings SET name = 'flags_default_topics' WHERE name = 'reviewable_default_topics'"
  end
end
