# frozen_string_literal: true
class SyncTimerableIdTopicId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    execute <<-SQL
      UPDATE topic_timers SET timerable_id = topic_id
    SQL
  end
end
