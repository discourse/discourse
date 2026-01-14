# frozen_string_literal: true
class ClearDuplicateAdminNotices < ActiveRecord::Migration[7.1]
  def up
    problem_subject_id = 0

    DB.exec(<<~SQL)
      DELETE FROM admin_notices
      WHERE subject = #{problem_subject_id}
    SQL
  end

  def down
  end
end
