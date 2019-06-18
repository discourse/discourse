# frozen_string_literal: true

class RemoveLikeCountFromPostMenu < ActiveRecord::Migration[5.2]
  def up
    execute(<<~SQL)
      UPDATE site_settings
      SET value = REGEXP_REPLACE(REPLACE(REPLACE(value, 'like-count', ''), '||', '|'), '^\\|', '')
      WHERE name = 'post_menu'
    SQL
  end
end
