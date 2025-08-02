# frozen_string_literal: true
class RemoveFullPageLoginProblemCheckTrackers < ActiveRecord::Migration[7.2]
  def up
    execute(<<~SQL)
      DELETE FROM problem_check_trackers WHERE identifier = 'full_page_login_check';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
