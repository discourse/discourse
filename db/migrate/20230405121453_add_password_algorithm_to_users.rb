# frozen_string_literal: true

class AddPasswordAlgorithmToUsers < ActiveRecord::Migration[7.0]
  def up
    add_column :users, :password_algorithm, :string, limit: 64
    execute <<~SQL
      UPDATE users SET password_algorithm = '$pbkdf2-sha256$i=64000,l=32$'
      WHERE users.password_hash IS NOT NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
