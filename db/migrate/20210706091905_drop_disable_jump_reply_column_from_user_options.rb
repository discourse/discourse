# frozen_string_literal: true

class DropDisableJumpReplyColumnFromUserOptions < ActiveRecord::Migration[6.1]
  DROPPED_COLUMNS ||= {
    user_options: %i{disable_jump_reply}
  }

  def up
    DROPPED_COLUMNS.each do |table, columns|
      Migration::ColumnDropper.execute_drop(table, columns)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
