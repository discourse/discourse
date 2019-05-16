# frozen_string_literal: true

class UpdateUsersCaseInsensitiveEmails < ActiveRecord::Migration[4.2]
  def up
    execute "DROP INDEX index_users_on_email"

    # Find duplicate emails.
    results = execute <<SQL
      SELECT id, email, count
        FROM (SELECT id, email,
                     row_number() OVER(PARTITION BY lower(email) ORDER BY id asc) AS count
                FROM users) dups
      WHERE dups.count > 1
SQL

    results.each do |row|
      execute "UPDATE users SET email = '#{row['email'].downcase}#{row['count']}' WHERE id = #{row['id']}"
    end

    execute "UPDATE users SET email = lower(email)"
    execute "CREATE UNIQUE INDEX index_users_on_email ON users ((lower(email)));"
  end

  def down
    execute "DROP INDEX index_users_on_email"
    execute "CREATE UNIQUE INDEX index_users_on_email ON users (email);"
  end
end
