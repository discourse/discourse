class AddLikeCountToPostMenu < ActiveRecord::Migration
  def up
    execute <<SQL
UPDATE site_settings
SET value = replace(value, 'like', 'like-count|like')
WHERE name = 'post_menu'
AND value NOT LIKE '%like-count%'
SQL
  end
end
