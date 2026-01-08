# frozen_string_literal: true

class RenameDiscourseRewindDisabledToEnabled < ActiveRecord::Migration[7.2]
  def up
    add_column :user_options, :discourse_rewind_enabled, :boolean, default: true, null: false

    execute <<~SQL
      UPDATE user_options
      SET discourse_rewind_enabled = NOT discourse_rewind_disabled
    SQL

    change_column_default :user_options, :discourse_rewind_disabled, nil

    Migration::ColumnDropper.mark_readonly(:user_options, :discourse_rewind_disabled)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:user_options, :discourse_rewind_disabled)

    change_column_default :user_options, :discourse_rewind_disabled, false

    remove_column :user_options, :discourse_rewind_enabled
  end
end
