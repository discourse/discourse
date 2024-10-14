# frozen_string_literal: true

class FixUniqueConstraintOnProblemCheckTrackers < ActiveRecord::Migration[7.1]
  def up
    remove_index :problem_check_trackers, %i[identifier target], if_exists: true

    # Remove any existing duplicates that might have slipped by to prevent
    # the creation of the new unique index from failing.
    #
    execute(<<~SQL)
      DELETE FROM problem_check_trackers
      WHERE id IN(
        SELECT pct1.id
        FROM problem_check_trackers pct1
        JOIN problem_check_trackers pct2
        ON pct1.identifier = pct2.identifier
        AND pct1.target IS NULL
        AND pct2.target IS NULL
        WHERE pct1.id > pct2.id
      )
    SQL

    add_index :problem_check_trackers, %i[identifier target], unique: true, nulls_not_distinct: true
  end

  def down
    remove_index :problem_check_trackers, %i[identifier target], if_exists: true
    add_index :problem_check_trackers, %i[identifier target], unique: true
  end
end
