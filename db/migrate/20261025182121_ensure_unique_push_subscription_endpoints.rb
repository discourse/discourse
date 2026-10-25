# frozen_string_literal: true

require "addressable/uri"

class EnsureUniquePushSubscriptionEndpoints < ActiveRecord::Migration[8.0]
  def up
    # Keep registrations from recreating duplicates before the index exists.
    execute "LOCK TABLE push_subscriptions IN SHARE ROW EXCLUSIVE MODE"
    normalize_endpoints
    execute <<~SQL
      DELETE FROM push_subscriptions
      WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY data::jsonb ->> 'endpoint' ORDER BY id DESC
          ) AS position
          FROM push_subscriptions
          WHERE data::jsonb ->> 'endpoint' IS NOT NULL
        ) duplicates
        WHERE position > 1
      )
    SQL

    add_index :push_subscriptions,
              "(data::jsonb ->> 'endpoint')",
              unique: true,
              name: "index_push_subscriptions_on_endpoint"
  end

  def down
    remove_index :push_subscriptions, name: "index_push_subscriptions_on_endpoint"
  end

  private

  def normalize_endpoints
    last_id = 0
    loop do
      rows =
        DB.query(
          "SELECT id, data FROM push_subscriptions WHERE id > :id ORDER BY id LIMIT 1000",
          id: last_id,
        )
      break if rows.empty?

      rows.each do |row|
        data = JSON.parse(row.data)
        endpoint = data["endpoint"]
        next if endpoint.blank?

        begin
          normalized = Addressable::URI.parse(endpoint).normalize.omit(:fragment).to_s
        rescue Addressable::URI::InvalidURIError
          next
        end
        next if endpoint == normalized

        data["endpoint"] = normalized
        DB.exec(
          "UPDATE push_subscriptions SET data = :data WHERE id = :id",
          data: data.to_json,
          id: row.id,
        )
      end
      last_id = rows.last.id
    end
  end
end
