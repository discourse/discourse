# frozen_string_literal: true

class DropEmailLogs < ActiveRecord::Migration[5.2]
  DROPPED_TABLES = %i[email_logs]

  def change
    drop_table :email_logs
    raise ActiveRecord::Rollback
  end
end
