# frozen_string_literal: true

class BackfillChannelSlugs < ActiveRecord::Migration[7.0]
  def up
    channels = DB.query(<<~SQL)
      SELECT chat_channels.id, COALESCE(chat_channels.name, categories.name) AS title, NULL as slug
      FROM chat_channels
      INNER JOIN categories ON categories.id = chat_channels.chatable_id
      WHERE chat_channels.chatable_type = 'Category' AND chat_channels.slug IS NULL
    SQL
    return if channels.count.zero?

    DB.exec("CREATE TEMPORARY TABLE tmp_chat_channel_slugs(id int, slug text)")

    taken_slugs = {}
    channels.each do |channel|
      # Simplified version of Slug.for generation that doesn't take into
      # account different encodings to make things a little easier.
      title = channel.title
      if title.blank?
        channel.slug = "channel-#{channel.id}"
      else
        channel.slug =
          title
            .downcase
            .chomp
            .tr("'", "")
            .parameterize
            .tr("_", "-")
            .truncate(255, omission: "")
            .squeeze("-")
            .gsub(/\A-+|-+\z/, "")
      end

      # Deduplicate slugs with the channel IDs, we can always improve
      # slugs later on.
      channel.slug = "#{channel.slug}-#{channel.id}" if taken_slugs.key?(channel.slug)
      taken_slugs[channel.slug] = true
    end

    values_to_insert =
      channels.map { |channel| "(#{channel.id}, '#{PG::Connection.escape_string(channel.slug)}')" }

    DB.exec(
      "INSERT INTO tmp_chat_channel_slugs
      VALUES #{values_to_insert.join(",\n")}",
    )

    DB.exec(<<~SQL)
      UPDATE chat_channels cc
      SET slug = tmp.slug
      FROM tmp_chat_channel_slugs tmp
      WHERE cc.id = tmp.id AND cc.slug IS NULL
    SQL

    DB.exec("DROP TABLE tmp_chat_channel_slugs")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
