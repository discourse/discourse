# frozen_string_literal: true

class RemoveAutoCloseColumnsFromTopics < ActiveRecord::Migration[4.2]
  def up
    # Defer dropping of the columns until the new application code has been deployed.
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
