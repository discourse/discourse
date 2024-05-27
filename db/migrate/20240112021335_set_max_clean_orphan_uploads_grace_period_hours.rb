# frozen_string_literal: true

class SetMaxCleanOrphanUploadsGracePeriodHours < ActiveRecord::Migration[7.0]
  def up
    DB.exec <<~SQL
        UPDATE site_settings SET value = '168' WHERE name ='clean_orphan_uploads_grace_period_hours' and value::int > 168;
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration.new
  end
end
