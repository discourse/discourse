# frozen_string_literal: true

class RemovePostProcessedTriggerOption < ActiveRecord::Migration[6.1]
  def up
    # Replace Badge::Trigger::PostProcessed (16) with None (0)
    DB.exec("UPDATE badges SET trigger = 0 WHERE trigger = 16")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
