# frozen_string_literal: true

module Migrations::Importer::Steps
  class TemplatedPermalinks < ::Migrations::Importer::CopyStep
    depends_on :simple_permalinks

    requires_set :existing_permalinks, "SELECT url FROM permalinks"

    table_name :permalinks
    column_names %i[url created_at updated_at external_url]

    total_rows_query <<~SQL
      SELECT COUNT(DISTINCT permalinks.url)
      FROM permalinks
           JOIN permalink_placeholders
             ON permalinks.url = permalink_placeholders.url
    SQL

    rows_query <<~SQL, MappingType::CATEGORIES, MappingType::TAGS
      SELECT permalinks.url,
             permalinks.external_url,
             JSON_GROUP_ARRAY(
              JSON_OBJECT(
                'placeholder', permalink_placeholders.placeholder,
                'target_type', permalink_placeholders.target_type,
                'target_id', permalink_placeholders.target_id,
                'target_discourse_id', COALESCE(mapped_category.discourse_id, mapped_tag.discourse_id)
              )
            ) AS placeholders
        FROM permalinks
            JOIN permalink_placeholders ON permalinks.url = permalink_placeholders.url
            LEFT JOIN mapped.ids mapped_category
              ON permalink_placeholders.target_type IN ('category_url', 'category_slug_ref')
                 AND permalink_placeholders.target_id = mapped_category.original_id
                 AND mapped_category.type = ?1
            LEFT JOIN mapped.ids mapped_tag
              ON permalink_placeholders.target_type = 'tag_name'
                 AND permalink_placeholders.target_id = mapped_tag.original_id
                 AND mapped_tag.type = ?2
      GROUP BY permalinks.url,
               permalinks.external_url
      ORDER BY permalinks.url
    SQL

    def execute
      category_ids = @intermediate_db.query_array(<<~SQL, MappingType::CATEGORIES).flatten
        SELECT DISTINCT mapped_category.discourse_id
        FROM mapped.ids mapped_category
             JOIN permalink_placeholders
               ON mapped_category.original_id = permalink_placeholders.target_id
                  AND permalink_placeholders.target_type IN ('category_url', 'category_slug_ref')
        WHERE mapped_category.type = ?
      SQL

      tag_ids = @intermediate_db.query_array(<<~SQL, MappingType::TAGS).flatten
        SELECT DISTINCT mapped_tag.discourse_id
        FROM mapped.ids mapped_tag
             JOIN permalink_placeholders
               ON mapped_tag.original_id = permalink_placeholders.target_id
                  AND permalink_placeholders.target_type = 'tag_name'
        WHERE mapped_tag.type = ?
      SQL

      # TODO:(selase)
      #     No need to instantiate Category and Tag models here
      #     Also category is bound to generate some N+1 queries for depths > 2
      #     We should be able generate the final cache using a SQL-only approach here
      categories =
        Category
          .includes(:parent_category)
          .where(id: category_ids)
          .select(:id, :slug, :parent_category_id)
      tags = Tag.where(id: tag_ids).select(:id, :name)

      @category_by_id = categories.index_by(&:id)
      @tag_by_id = tags.index_by(&:id)

      super
    end

    private

    def transform_row(row)
      return nil unless @existing_permalinks.add?(row[:url])

      placeholders = JSON.parse(row[:placeholders], symbolize_names: true)
      replacements = {}
      replacement_errors = []

      placeholders.each do |placeholder|
        target_discourse_id = placeholder[:target_discourse_id]

        unless target_discourse_id
          replacement_errors << "Placeholder '#{placeholder[:placeholder]}' target not found. " \
            "ID: #{placeholder[:target_id]}, Type: #{placeholder[:target_type]}"
          next
        end

        case placeholder[:target_type]
        when "category_url"
          if (category = @category_by_id[target_discourse_id])
            replacements[
              placeholder[:placeholder]
            ] = "c/#{category.slug_path.join("/")}/#{category.id}"
          else
            replacement_errors << "Category not found. ID: #{target_discourse_id}"
          end
        when "category_slug_ref"
          if (category = @category_by_id[target_discourse_id])
            replacements[placeholder[:placeholder]] = category.slug_ref
          else
            replacement_errors << "Category not found. ID: #{target_discourse_id}"
          end
        when "tag_name"
          if (tag = @tag_by_id[target_discourse_id])
            replacements[placeholder[:placeholder]] = tag.name
          else
            replacement_errors << "Tag not found. ID: #{target_discourse_id}"
          end
        else
          raise "Unknown placeholder type: #{placeholder[:target_type]}"
        end
      end

      if replacement_errors.any?
        puts "    Permalink '#{row[:url]}' has the following placeholder errors:"
        replacement_errors.each { |error| puts "      #{error}" }

        return nil if replacements.empty?
      end

      pattern = /#{replacements.keys.map { |k| Regexp.escape(k) }.join("|")}/
      row[:external_url] = row[:external_url].gsub(pattern, replacements)

      super
    end
  end
end
