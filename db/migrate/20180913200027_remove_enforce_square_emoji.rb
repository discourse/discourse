# frozen_string_literal: true

class RemoveEnforceSquareEmoji < ActiveRecord::Migration[5.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enforce_square_emoji'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
