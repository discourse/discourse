# frozen_string_literal: true

module Migrations::Importer::Steps
  class Tags < Base::Tags
    total_rows_query <<~SQL, MappingType::TAGS
      SELECT COUNT(*)
      FROM tags
           LEFT JOIN tag_synonyms
             ON tags.original_id = tag_synonyms.synonym_tag_id
           LEFT JOIN mapped.ids mapped_tag
             ON tags.original_id = mapped_tag.original_id AND mapped_tag.type = ?
      WHERE mapped_tag.original_id IS NULL
        AND tag_synonyms.synonym_tag_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::TAGS
      SELECT tags.*
      FROM tags
           LEFT JOIN tag_synonyms
             ON tags.original_id = tag_synonyms.synonym_tag_id
           LEFT JOIN mapped.ids mapped_tag
             ON tags.original_id = mapped_tag.original_id AND mapped_tag.type = ?
      WHERE mapped_tag.original_id IS NULL
        AND tag_synonyms.synonym_tag_id IS NULL
      ORDER BY tags.original_id
    SQL
  end
end
