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

    batch_size = 500
    begin
      batch = DB.query <<-SQL
        SELECT id, key
        FROM api_keys
        WHERE key_hash IS NULL
        LIMIT #{batch_size}
      SQL

      to_update = []
      for row in batch
        hashed = Digest::SHA256.hexdigest row.key
        to_update << { id: row.id, key_hash: hashed }
      end

      if to_update.size > 0
        data_string = to_update.map { |r| "(#{r[:id]}, '#{r[:key_hash]}')" }.join(",")

        DB.exec <<~SQL
          UPDATE api_keys
          SET key_hash = data.key_hash
          FROM (values
            #{data_string}
          ) as data(id, key_hash)
          WHERE api_keys.id = data.id
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
