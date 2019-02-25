require 'migration/column_dropper'

class DropGroupLockedTrustLevelFromUser < ActiveRecord::Migration[5.2]
  def up
    Migration::ColumnDropper.execute_drop(:posts, %i{group_locked_trust_level})
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
