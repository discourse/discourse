# frozen_string_literal: true

class DropUserStatCountConstraints < ActiveRecord::Migration[6.1]
  def up
    execute "ALTER TABLE user_stats DROP CONSTRAINT topic_count_positive"
    execute "ALTER TABLE user_stats DROP CONSTRAINT post_count_positive"
  end

  def down
    execute(<<~SQL)
    UPDATE user_stats
    SET post_count = 0
    WHERE post_count < 0
    SQL

    execute(<<~SQL)
    UPDATE user_stats
    SET topic_count = 0
    WHERE topic_count < 0
    SQL

    execute "ALTER TABLE user_stats ADD CONSTRAINT topic_count_positive CHECK (topic_count >= 0)"
    execute "ALTER TABLE user_stats ADD CONSTRAINT post_count_positive CHECK (post_count >= 0)"
  end
end
