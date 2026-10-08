# frozen_string_literal: true

class MarkPotentiallyIllegalReadonly < ActiveRecord::Migration[8.1]
  def up
    change_column_default :reviewables, :potentially_illegal, nil
    Migration::ColumnDropper.mark_readonly(:reviewables, :potentially_illegal)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:reviewables, :potentially_illegal)
    change_column_default :reviewables, :potentially_illegal, false
  end
end
