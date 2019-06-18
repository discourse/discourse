# frozen_string_literal: true

class AddLikeCountToPostMenu < ActiveRecord::Migration[4.2]
  def up
    execute <<SQL
UPDATE site_settings
SET value = replace(value, 'like', 'like-count|like')
WHERE name = 'post_menu'
AND value NOT LIKE '%like-count%'
SQL
  end
end
