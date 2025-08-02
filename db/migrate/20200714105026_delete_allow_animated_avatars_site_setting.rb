# frozen_string_literal: true

class DeleteAllowAnimatedAvatarsSiteSetting < ActiveRecord::Migration[6.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'allow_animated_avatars'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration.new
  end
end
