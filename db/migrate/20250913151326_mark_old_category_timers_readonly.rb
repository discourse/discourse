# frozen_string_literal: true
class MarkOldCategoryTimersReadonly < ActiveRecord::Migration[8.0]
  def up
    # drop default value of the column first
    change_column_null :categories, :auto_close_hours, true
    change_column_default :categories, :auto_close_based_on_last_post, nil

    Migration::ColumnDropper.mark_readonly(:categories, :auto_close_hours)
    Migration::ColumnDropper.mark_readonly(:categories, :auto_close_based_on_last_post)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:categories, :auto_close_based_on_last_post)
    Migration::ColumnDropper.drop_readonly(:categories, :auto_close_hours)

    change_column_default :categories, :auto_close_based_on_last_post, true
    change_column_null :categories, :auto_close_hours, false
  end
end
