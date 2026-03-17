# frozen_string_literal: true

class CleanExistingTagLocalizationNames < ActiveRecord::Migration[7.2]
  # matches DiscourseTagging::TAGS_FILTER_REGEXP plus whitespace and consecutive dashes
  VIOLATING_PATTERN = %q{[/:?#\[\]@!$&'()*+,;=.%\\`^\s|{}"<>]|--}

  def up
    conditions = ["name ~ :pattern OR name != TRIM(name)"]
    params = { pattern: VIOLATING_PATTERN }

    conditions << "name != LOWER(name)" if SiteSetting.force_lowercase_tags

    max_length = SiteSetting.max_tag_length
    conditions << "LENGTH(name) > :max_length"
    params[:max_length] = max_length

    query = <<~SQL
      SELECT id, name FROM tag_localizations
      WHERE #{conditions.join(" OR ")}
    SQL

    DB
      .query(query, **params)
      .each do |row|
        cleaned = DiscourseTagging.clean_tag(row.name)
        next if cleaned == row.name
        next if cleaned.blank?

        DB.exec(
          "UPDATE tag_localizations SET name = :name WHERE id = :id",
          name: cleaned,
          id: row.id,
        )
      end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
