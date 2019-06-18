# frozen_string_literal: true

class RenameSiteSettings < ActiveRecord::Migration[4.2]

  def up
    execute "UPDATE site_settings SET name = 'allow_restore' WHERE name = 'allow_import'"
    execute "UPDATE site_settings SET name = 'topics_per_period_in_top_summary' WHERE name = 'topics_per_period_in_summary'"
  end

  def down
    execute "UPDATE site_settings SET name = 'allow_import' WHERE name = 'allow_restore'"
    execute "UPDATE site_settings SET name = 'topics_per_period_in_summary' WHERE name = 'topics_per_period_in_top_summary'"
  end

end
