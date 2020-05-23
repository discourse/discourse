# frozen_string_literal: true

class RemoveFlagWebHooks < ActiveRecord::Migration[6.0]
  def up
    flag_event_type_id = 7

    DB.exec <<~SQL
    DELETE FROM web_hook_event_types_hooks
    WHERE web_hook_event_type_id = #{flag_event_type_id}
    SQL

    DB.exec <<~SQL
    DELETE FROM web_hook_event_types
    WHERE id = #{flag_event_type_id}
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
