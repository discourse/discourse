# frozen_string_literal: true

module Migrations::Importer::Steps
  class TagSynonyms < Base::Tags
    depends_on :tags

    requires_set :existing_synonym_tag_ids, "SELECT id FROM tags WHERE target_tag_id IS NOT NULL"

    total_rows_query <<~SQL, MappingType::TAGS
      SELECT COUNT(*)
      FROM tag_synonyms
        JOIN mapped.ids mapped_target_tag
          ON tag_synonyms.target_tag_id = mapped_target_tag.original_id
             AND mapped_target_tag.type = ?1
        LEFT JOIN mapped.ids mapped_synonym_tag
          ON tag_synonyms.synonym_tag_id = mapped_synonym_tag.original_id
             AND mapped_synonym_tag.type = ?1
      WHERE mapped_synonym_tag.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::TAGS
      SELECT tags.*,
             tag_synonyms.target_tag_id     AS original_target_tag_id,
             mapped_target_tag.discourse_id AS discourse_target_tag_id
      FROM tags
           JOIN tag_synonyms ON tags.original_id = tag_synonyms.synonym_tag_id
           JOIN mapped.ids mapped_target_tag
             ON tag_synonyms.target_tag_id = mapped_target_tag.original_id
                AND mapped_target_tag.type = ?1
           LEFT JOIN mapped.ids mapped_synonym_tag
             ON tags.original_id = mapped_synonym_tag.original_id
                AND mapped_synonym_tag.type = ?1
      WHERE mapped_synonym_tag.original_id IS NULL
      ORDER BY tags.original_id
    SQL

    def load_validation_caches
      @synonym_target_tag_ids = Set.new
      @synonym_tag_ids = Set.new

      @intermediate_db
        .query_array("SELECT synonym_tag_id, target_tag_id FROM tag_synonyms")
        .each do |synonym_id, target_id|
          @synonym_tag_ids.add(synonym_id)
          @synonym_target_tag_ids.add(target_id)
        end
    end

    def apply_transforms(row)
      original_id = row[:original_id]
      name = row[:name]

      if @synonym_target_tag_ids.include?(original_id)
        puts "    Tag '#{name}' cannot become a synonym because it already has synonyms"

        return nil
      end

      original_target_tag_id = row[:original_target_tag_id]
      discourse_target_tag_id = row[:discourse_target_tag_id]

      if @synonym_tag_ids.include?(original_target_tag_id) ||
           @existing_synonym_tag_ids.include?(discourse_target_tag_id)
        puts "    Tag '#{name}' cannot point to another synonym tag (target_tag_id: #{original_target_tag_id})"
        return nil
      end

      if original_id == original_target_tag_id
        puts "    Tag '#{name}' cannot be synonym of itself"

        return nil
      end

      row[:target_tag_id] = discourse_target_tag_id

      row
    end
  end
end
