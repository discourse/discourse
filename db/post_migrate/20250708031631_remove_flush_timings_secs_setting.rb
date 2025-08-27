# frozen_string_literal: true

class RemoveFlushTimingsSecsSetting < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'flush_timings_secs';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
