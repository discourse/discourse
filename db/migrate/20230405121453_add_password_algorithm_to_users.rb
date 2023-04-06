# frozen_string_literal: true

class AddPasswordAlgorithmToUsers < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  BATCH_SIZE = 5000

  def up
    if !column_exists?(:users, :password_algorithm)
      add_column :users, :password_algorithm, :string, limit: 64
    end

    sql = <<~SQL
      UPDATE users SET password_algorithm = '$pbkdf2-sha256$i=64000,l=32$'
      WHERE id IN (
        SELECT id FROM users
        WHERE users.password_hash IS NOT NULL
        AND users.password_algorithm IS NULL
        LIMIT #{BATCH_SIZE}
      )
    SQL

    loop do
      changed_count = execute(sql).cmd_tuples
      break if changed_count < BATCH_SIZE
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
