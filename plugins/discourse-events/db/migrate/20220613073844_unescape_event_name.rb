# frozen_string_literal: true

class UnescapeEventName < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  TEMP_INDEX_NAME = "_temp_discourse_calendar_unescape_event_name_migration"

  def up
    # event notifications
    DB.exec(
      "CREATE INDEX CONCURRENTLY #{TEMP_INDEX_NAME} ON notifications(id) WHERE notification_type IN (27, 28)",
    )
    start, limit =
      DB.query_single(
        "SELECT MIN(id), MAX(id) FROM notifications WHERE notification_type IN (27, 28)",
      )

    return if !start

    notifications_query = <<~SQL
      SELECT id, data
      FROM notifications
      WHERE
        id >= :start AND
        notification_type IN (27, 28) AND
        data::json ->> 'topic_title' LIKE '%&%'
      ORDER BY id ASC
      LIMIT 10000
    SQL

    while true
      break if start > limit

      max_seen = -1

      DB
        .query(notifications_query, start: start)
        .each do |record|
          id = record.id

          max_seen = id if id > max_seen

          data = JSON.parse(record.data)
          unescaped = CGI.unescapeHTML(data["topic_title"])
          next if unescaped == data["topic_title"]
          data["topic_title"] = unescaped

          DB.exec(<<~SQL, data: data.to_json, id: id)
          UPDATE notifications SET data = :data WHERE id = :id
        SQL
        end

      start += 10_000

      start = max_seen + 1 if max_seen > start
    end

    # event names
    events_query = <<~SQL
      SELECT id, name
      FROM discourse_post_event_events
      WHERE name LIKE '%&%'
      ORDER BY id ASC
    SQL

    DB
      .query(events_query)
      .each do |event|
        unescaped_name = CGI.unescapeHTML(event.name)
        next if unescaped_name == event.name
        DB.exec(<<~SQL, unescaped_name: unescaped_name, id: event.id)
        UPDATE discourse_post_event_events SET name = :unescaped_name WHERE id = :id
      SQL
      end
  ensure
    DB.exec("DROP INDEX IF EXISTS #{TEMP_INDEX_NAME}")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
