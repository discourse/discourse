# frozen_string_literal: true
class SolvedFixHighAutoCloseTopicHours < ActiveRecord::Migration[6.0]
  def up
    execute <<-SQL
      UPDATE site_settings
         SET value = '175000'
       WHERE name = 'solved_topics_auto_close_hours'
         AND CAST(value AS INT) > 175000
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
