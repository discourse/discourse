# frozen_string_literal: true
class RemoveAllButMostRecentUserPassword < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      DELETE FROM user_passwords
      WHERE id NOT IN (
        SELECT DISTINCT ON (user_id) id
        FROM user_passwords
        ORDER BY user_id, password_expired_at DESC NULLS FIRST
      );
    SQL
  end

  def down
  end
end
