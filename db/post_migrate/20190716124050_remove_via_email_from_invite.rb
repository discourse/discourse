# frozen_string_literal: true

require 'migration/column_dropper'

class RemoveViaEmailFromInvite < ActiveRecord::Migration[5.2]
  def up
    Migration::ColumnDropper.execute_drop(:invites, %i{via_email})
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
