# frozen_string_literal: true

class AlterWebHookEventsIdToBigint < ActiveRecord::Migration[7.2]
  def up
    change_column :web_hook_events, :id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
