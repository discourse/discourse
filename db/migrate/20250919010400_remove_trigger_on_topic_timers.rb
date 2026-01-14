# frozen_string_literal: true

class RemoveTriggerOnTopicTimers < ActiveRecord::Migration[8.0]
  def up
    execute("DROP FUNCTION IF EXISTS mirror_topic_timers_topic_id() CASCADE;")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
