# frozen_string_literal: true

# TODO: Remove this when releasing Discourse 3.6
class MigrateSidekiqJobs < ActiveRecord::Migration[7.2]
  def up
    SidekiqMigration.call
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
