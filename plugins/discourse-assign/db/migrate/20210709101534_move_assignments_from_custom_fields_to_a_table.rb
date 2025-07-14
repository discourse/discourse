# frozen_string_literal: true

class MoveAssignmentsFromCustomFieldsToATable < ActiveRecord::Migration[6.1]
  def up
    # No-op, this migration was invalid
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
