# frozen_string_literal: true
class AddDefaultValueToProblemCheckTrackersTarget < ActiveRecord::Migration[7.1]
  def up
    change_column_default :problem_check_trackers, :target, "__NULL__"

    execute(<<~SQL)
      UPDATE problem_check_trackers
      SET target='__NULL__'
      WHERE target IS NULL
    SQL
  end

  def down
    change_column_default :problem_check_trackers, :target, nil

    execute(<<~SQL)
      UPDATE problem_check_trackers
      SET target = NULL
      WHERE target = '__NULL__'
    SQL
  end
end
