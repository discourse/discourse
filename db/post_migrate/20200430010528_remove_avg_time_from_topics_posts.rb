# frozen_string_literal: true

class RemoveAvgTimeFromTopicsPosts < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    # this makes it re-runnable and also works if it was not created initially
    execute <<~SQL
      ALTER TABLE topics DROP COLUMN IF EXISTS avg_time CASCADE
    SQL

    execute <<~SQL
      ALTER TABLE posts DROP COLUMN IF EXISTS avg_time CASCADE
    SQL
  end

  def down
    # do nothing re-runnable
  end
end
