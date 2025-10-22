# frozen_string_literal: true
class NullifyBlankLocales < ActiveRecord::Migration[7.2]
  def up
    loop do
      result = execute(<<~SQL)
          UPDATE topics
          SET locale = NULL
          WHERE id IN (SELECT id FROM topics WHERE locale = '' LIMIT 5000)
        SQL

      break if result.cmd_tuples == 0
    end

    loop do
      result = execute(<<~SQL)
          UPDATE posts
          SET locale = NULL
          WHERE id IN (SELECT id FROM posts WHERE locale = '' LIMIT 5000)
        SQL

      break if result.cmd_tuples == 0
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
