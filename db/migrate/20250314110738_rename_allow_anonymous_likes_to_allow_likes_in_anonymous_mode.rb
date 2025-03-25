# frozen_string_literal: true

class RenameAllowAnonymousLikesToAllowLikesInAnonymousMode < ActiveRecord::Migration[7.2]
  def up
    execute(<<~SQL)
      UPDATE site_settings
      SET name = 'allow_likes_in_anonymous_mode'
      WHERE name = 'allow_anonymous_likes'
    SQL
  end

  def down
    execute(<<~SQL)
      UPDATE site_settings
      SET name = 'allow_anonymous_likes'
      WHERE name = 'allow_likes_in_anonymous_mode'
    SQL
  end
end
