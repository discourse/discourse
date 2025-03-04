# frozen_string_literal: true

# Delete this migration instead of promoting it (along with the
# `SidekiqMigration` class)
class MigrateSidekiqJobs < ActiveRecord::Migration[7.2]
  def up
    SidekiqMigration.call
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
