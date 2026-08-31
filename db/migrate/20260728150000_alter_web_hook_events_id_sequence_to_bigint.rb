# frozen_string_literal: true

class AlterWebHookEventsIdSequenceToBigint < ActiveRecord::Migration[8.0]
  def up
    execute "ALTER SEQUENCE web_hook_events_id_seq AS bigint"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
