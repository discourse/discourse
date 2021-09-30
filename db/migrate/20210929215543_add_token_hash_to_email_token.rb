# frozen_string_literal: true

class AddTokenHashToEmailToken < ActiveRecord::Migration[6.1]
  def up
    add_column :email_tokens, :token_hash, :string

    loop do
      rows = DB
        .query("SELECT id, token FROM email_tokens WHERE token_hash IS NULL LIMIT 500")
        .map { |row| { id: row.id, token_hash: Digest::SHA256.hexdigest(row.token) } }

      break if rows.size == 0

      data_string = rows.map { |r| "(#{r[:id]}, '#{r[:token_hash]}')" }.join(",")
      execute <<~SQL
        UPDATE email_tokens
        SET token_hash = data.token_hash
        FROM (VALUES #{data_string}) AS data(id, token_hash)
        WHERE email_tokens.id = data.id
      SQL
    end

    change_column_null :email_tokens, :token_hash, false
  end

  def down
    drop_column :email_tokens, :token_hash, :string
  end
end
