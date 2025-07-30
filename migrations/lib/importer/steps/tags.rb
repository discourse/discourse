# frozen_string_literal: true

module Migrations::Importer::Steps
  class Tags < ::Migrations::Importer::CopyStep
    include ::HasSanitizableFields

    MAX_DESCRIPTION_LENGTH = 1000

    store_mapped_ids true
    requires_mapping :existing_tag_by_name, "SELECT LOWER(name), id FROM tags"

    column_names %i[id name description target_tag_id created_at updated_at]

    total_rows_query <<~SQL, MappingType::TAGS
      SELECT COUNT(*)
      FROM tags
           LEFT JOIN mapped.ids mapped_tag
            ON tags.original_id = mapped_tag.original_id AND mapped_tag.type = ?
      WHERE mapped_tag.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::TAGS
      SELECT tags.*
      FROM tags
          LEFT JOIN mapped.ids mapped_tag
            ON tags.original_id = mapped_tag.original_id AND mapped_tag.type = ?
      WHERE mapped_tag.original_id IS NULL
      ORDER BY tags.target_tag_id, tags.ROWID
    SQL

    def execute
      # TODO(selase): Copying this over as-is from the current importer.
      #               Why 100?
      #               Should we restore the value at the end of the step?
      SiteSetting.max_tag_length = 100 if SiteSetting.max_tag_length < 100

      @mapped_tag_ids = @intermediate_db.query_array(<<~SQL, MappingType::TAGS).to_h
        SELECT original_id, discourse_id FROM  mapped.ids WHERE type = ?
      SQL

      super
    end

    def transform_row(row)
      name = DiscourseTagging.clean_tag(row[:name])

      if (existing_id = @existing_tag_by_name[name.downcase])
        row[:id] = existing_id

        # Store mapping for the existing tag. It's needed for
        # `target_tag_id` which is self-referential
        @mapped_tag_ids[row[:original_id]] = row[:id]

        return nil
      end

      row[:name] = name
      row[:description] = sanitize_field(row[:description])[0...MAX_DESCRIPTION_LENGTH] if row[
        :description
      ]

      if (original_target_tag_id = row[:target_tag_id])
        discourse_target_tag_id = @mapped_tag_ids[original_target_tag_id]

        unless discourse_target_tag_id
          puts "    Tag '#{name}' has unresolved target_tag_id: #{original_target_tag_id}"
          return nil
        end

        row[:target_tag_id] = discourse_target_tag_id
      end

      super

      # Store mapping for the new tag. It's needed for
      # `target_tag_id` which is self-referential
      @mapped_tag_ids[row[:original_id]] = row[:id]

      row
    end
  end
end
