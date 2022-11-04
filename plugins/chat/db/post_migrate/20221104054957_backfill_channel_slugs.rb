# frozen_string_literal: true

class BackfillChannelSlugs < ActiveRecord::Migration[7.0]
  def up
    channels = DB.query(<<~SQL)
      SELECT chat_channels.id, COALESCE(chat_channels.name, categories.name) AS title, NULL as slug
      FROM chat_channels
      INNER JOIN categories ON categories.id = chat_channels.chatable_id
      WHERE chat_channels.chatable_type = 'Category'
    SQL

    DB.exec("CREATE TEMPORARY TABLE tmp_chat_channel_slugs(id int, slug text)")

    taken_slugs = {}
    channels.each do |channel|
      # Simplified version of Slug.for generation that doesn't take into
      # account different encodings to make things a little easier.
      channel.slug =
        channel
          .title
          .downcase
          .chomp
          .tr("'", "")
          .parameterize
          .tr("_", "-")
          .truncate(255, omission: "")
          .squeeze("-")
          .gsub(/\A-+|-+\z/, "")

      # Deduplicate slugs with the channel IDs, we can always improve
      # slugs later on.
      if taken_slugs.key?(channel.slug)
        channel.slug = "#{channel.slug}-#{channel.id}"
      end
      taken_slugs[channel.slug] = true
    end

    values_to_insert = channels.map do |channel|
      "(#{channel.id}, '#{PG::Connection.escape_string(channel.slug)}')"
    end

    DB.exec(
      "INSERT INTO tmp_chat_channel_slugs
      VALUES #{values_to_insert.join(",\n")}"
    )

    DB.exec(<<~SQL)
      UPDATE chat_channels cc
      SET slug = tmp.slug
      FROM tmp_chat_channel_slugs tmp
      WHERE cc.id = tmp.id
    SQL
  end

  def down
    # raise ActiveRecord::IrreversibleMigration
  end
end
