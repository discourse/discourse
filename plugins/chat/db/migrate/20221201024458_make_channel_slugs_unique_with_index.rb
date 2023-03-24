# frozen_string_literal: true

class MakeChannelSlugsUniqueWithIndex < ActiveRecord::Migration[7.0]
  def up
    DB.exec("CREATE TEMPORARY TABLE tmp_chat_channel_slugs_conflicts(id int, slug text)")

    channels_with_conflicting_slugs = DB.query(<<~SQL)
      SELECT chat_channels.id, subquery.slug
      FROM (
        SELECT slug, count(*)
        FROM chat_channels
        GROUP BY slug
        HAVING count(*) > 1
      ) subquery
      INNER JOIN chat_channels ON chat_channels.slug = subquery.slug
      ORDER BY slug, created_at ASC
    SQL

    current_slug = nil
    slugs_to_update = []
    channels_with_conflicting_slugs.each do |channel|
      if current_slug != channel.slug
        current_slug = channel.slug

        # Continue since we want to keep the slug for the first
        # matching channel and just update subsequent channels.
        next
      end

      # Deduplicate slugs with the channel IDs, we can always improve
      # slugs later on.
      slugs_to_update << [channel.id, "#{channel.slug}-#{channel.id}"]
    end

    values_to_insert =
      slugs_to_update.map do |channel_pair|
        "(#{channel_pair[0]}, '#{PG::Connection.escape_string(channel_pair[1])}')"
      end

    if values_to_insert.any?
      DB.exec(
        "INSERT INTO tmp_chat_channel_slugs_conflicts
        VALUES #{values_to_insert.join(",\n")}",
      )

      DB.exec(<<~SQL)
        UPDATE chat_channels cc
        SET slug = tmp.slug
        FROM tmp_chat_channel_slugs_conflicts tmp
        WHERE cc.id = tmp.id
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
