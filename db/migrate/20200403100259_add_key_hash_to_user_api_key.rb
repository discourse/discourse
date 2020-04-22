# frozen_string_literal: true

class AddKeyHashToUserApiKey < ActiveRecord::Migration[6.0]
  def up
    add_column :user_api_keys, :key_hash, :string

    batch_size = 500
    loop do
      rows = DB
        .query("SELECT id, key FROM user_api_keys WHERE key_hash IS NULL LIMIT #{batch_size}")
        .map { |row| { id: row.id, key_hash: Digest::SHA256.hexdigest(row.key) } }

      break if rows.size == 0

      data_string = rows.map { |r| "(#{r[:id]}, '#{r[:key_hash]}')" }.join(",")
      execute <<~SQL
        UPDATE user_api_keys
        SET key_hash = data.key_hash
        FROM (VALUES #{data_string}) AS data(id, key_hash)
        WHERE user_api_keys.id = data.id
      SQL

      break if rows.size < batch_size
    end

    change_column_null :user_api_keys, :key_hash, false
  end

  def down
    drop_column :user_api_keys, :key_hash, :string
  end
end
