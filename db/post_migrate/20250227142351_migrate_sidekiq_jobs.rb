# frozen_string_literal: true

# TODO: Remove this after the Discourse 3.5 release
class MigrateSidekiqJobs < ActiveRecord::Migration[7.2]
  def up
    SidekiqMigration.call
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
