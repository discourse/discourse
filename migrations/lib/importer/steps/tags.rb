# frozen_string_literal: true

module Migrations::Importer::Steps
  class Tags < ::Migrations::Importer::CopyStep
    include ::HasSanitizableFields

    MAX_DESCRIPTION_LENGTH = 1000
    RESERVED_TAGS = Tag::RESERVED_TAGS.to_set.freeze

    requires_set :existing_synonym_tag_ids, "SELECT id FROM tags WHERE target_tag_id IS NOT NULL"
    requires_mapping :existing_tag_by_name, "SELECT LOWER(name), id FROM tags"

    column_names %i[id name description target_tag_id created_at updated_at]

    store_mapped_ids true

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
      max_tag_length = @intermediate_db.query_value("SELECT MAX(LENGTH(name)) FROM tags") || 0
      SiteSetting.max_tag_length = max_tag_length if SiteSetting.max_tag_length < max_tag_length

      @mapped_tag_ids = @intermediate_db.query_array(<<~SQL, MappingType::TAGS).to_h
        SELECT original_id, discourse_id FROM  mapped.ids WHERE type = ?
      SQL

      synonym_pairs_sql =
        "SELECT original_id, target_tag_id FROM tags WHERE target_tag_id IS NOT NULL"
      @synonym_target_tag_ids = Set.new
      @synonym_tag_ids = Set.new

      @intermediate_db
        .query_array(synonym_pairs_sql)
        .each do |synonym_id, target_id|
          @synonym_tag_ids.add(synonym_id)
          @synonym_target_tag_ids.add(target_id)
        end

      super
    end

    def transform_row(row)
      name = DiscourseTagging.clean_tag(row[:name])
      name_lower = name.downcase

      if (existing_id = @existing_tag_by_name[name_lower])
        row[:id] = existing_id

        # Store mapping for the existing tag. It might be needed for
        # the self-referential `target_tag_id` resolution later
        @mapped_tag_ids[row[:original_id]] = row[:id]

        return nil
      end

      if RESERVED_TAGS.include?(name_lower)
        puts "    Tag '#{name}' is reserved"
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

        if @synonym_target_tag_ids.include?(row[:original_id])
          puts "    Tag '#{name}' cannot become a synonym because it already has synonyms"
          return nil
        end

        if @synonym_tag_ids.include?(original_target_tag_id) ||
             @existing_synonym_tag_ids.include?(discourse_target_tag_id)
          puts "    Tag '#{name}' cannot point to another synonym tag (target_tag_id: #{original_target_tag_id})"
          return nil
        end

        row[:target_tag_id] = discourse_target_tag_id
      end

      super

      # Store mapping for the new tag. It might be needed for
      # the self-referential `target_tag_id` resolution later
      @mapped_tag_ids[row[:original_id]] = row[:id]

      row
    end
  end
end
