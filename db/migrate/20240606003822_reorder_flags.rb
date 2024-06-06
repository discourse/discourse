# frozen_string_literal: true

class ReorderFlags < ActiveRecord::Migration[7.0]
  def up
    current_order = DB.query(<<~SQL)
      SELECT name FROM flags
      WHERE score_type IS FALSE
      ORDER BY position ASC
    SQL

    if current_order.map(&:name) ==
         %w[notify_user notify_moderators off_topic inappropriate spam illegal]
      execute "UPDATE flags SET position = 0 WHERE name = 'notify_user'"
      execute "UPDATE flags SET position = 1 WHERE name = 'off_topic'"
      execute "UPDATE flags SET position = 2 WHERE name = 'inappropriate'"
      execute "UPDATE flags SET position = 3 WHERE name = 'spam'"
      execute "UPDATE flags SET position = 4 WHERE name = 'illegal'"
      execute "UPDATE flags SET position = 5 WHERE name = 'notify_moderators'"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
