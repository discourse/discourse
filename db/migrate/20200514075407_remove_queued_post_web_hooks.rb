# frozen_string_literal: true

class RemoveQueuedPostWebHooks < ActiveRecord::Migration[6.0]
  def up
    queued_post_event_type_id = 8

    DB.exec <<~SQL
    DELETE FROM web_hook_event_types_hooks
    WHERE web_hook_event_type_id = #{queued_post_event_type_id}
    SQL

    DB.exec <<~SQL
    DELETE FROM web_hook_event_types
    WHERE id = #{queued_post_event_type_id}
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
