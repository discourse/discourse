# frozen_string_literal: true

class UpdatePasswordAlgorithmPostDeploy < ActiveRecord::Migration[7.0]
  def up
    # Handles any users that were created by old-version app code since
    # the 20230405121453 pre-deploy migration was run
    execute <<~SQL
      UPDATE users SET password_algorithm = '$pbkdf2-sha256$i=64000,l=32$'
      WHERE users.password_algorithm IS NULL
      AND users.password_hash IS NOT NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
