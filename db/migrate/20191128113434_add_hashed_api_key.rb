# frozen_string_literal: true
class AddHashedApiKey < ActiveRecord::Migration[6.0]
  def up
    add_column(:api_keys, :key_hash, :string)
    add_column(:api_keys, :truncated_key, :string)

    execute(
      <<~SQL
        UPDATE api_keys
        SET truncated_key = LEFT(key, 4)
      SQL
    )

    batch_size = 100
    begin
      batch = ActiveRecord::Base.connection.select_all <<-SQL
        SELECT id, key
        FROM api_keys
        WHERE key_hash IS NULL
        LIMIT #{batch_size}
      SQL

      for row in batch
        hashed = Digest::SHA256.hexdigest row["key"]
        execute <<~SQL
          UPDATE api_keys
          SET key_hash = '#{hashed}'
          WHERE id = #{row["id"]}
        SQL
      end
    end until batch.length < batch_size

    change_column_null :api_keys, :key_hash, false
    change_column_null :api_keys, :truncated_key, false

    add_index :api_keys, :key_hash

    # The key column will be dropped in a post_deploy migration
    # But allow it to be null in the meantime
    Migration::SafeMigrate.disable!
    change_column_null :api_keys, :key, true
    Migration::SafeMigrate.enable!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
