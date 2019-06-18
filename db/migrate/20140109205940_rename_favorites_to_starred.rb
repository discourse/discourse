# frozen_string_literal: true

class RenameFavoritesToStarred < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE site_settings SET name = 'max_stars_per_day' where name = 'max_favorites_per_day'"
    execute "UPDATE site_settings SET value = REPLACE(value, '|favorited', '|starred') where name = 'top_menu'"
  end

  def down
    execute "UPDATE site_settings SET name = 'max_favorites_per_day' where name = 'max_stars_per_day'"
    execute "UPDATE site_settings SET value = REPLACE(value, '|starred', '|favorited') where name = 'top_menu'"
  end
end
