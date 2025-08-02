# frozen_string_literal: true
#
class RemoveGlimmerHeaderModeSetting < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'glimmer_header_mode'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
