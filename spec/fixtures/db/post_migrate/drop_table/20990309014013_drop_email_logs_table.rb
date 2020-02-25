# frozen_string_literal: true

class DropEmailLogsTable < ActiveRecord::Migration[5.2]
  DROPPED_TABLES ||= %i{email_logs}

  def up
    drop_table :email_logs
    raise ActiveRecord::Rollback
  end

  def down
    raise "not tested"
  end
end
