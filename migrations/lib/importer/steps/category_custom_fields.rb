# frozen_string_literal: true

module Migrations::Importer::Steps
  class CategoryCustomFields < ::Migrations::Importer::CopyStep
    depends_on :categories

    requires_set :existing_custom_fields,
                 "SELECT category_id || ':' || name FROM category_custom_fields"

    column_names %i[category_id name value created_at updated_at]

    total_rows_query <<~SQL, MappingType::CATEGORIES
      SELECT COUNT(*)
      FROM category_custom_fields custom_fields
           JOIN mapped.ids mapped_categories
             ON custom_fields.category_id = mapped_categories.original_id AND mapped_categories.type = ?
    SQL

    rows_query <<~SQL, MappingType::CATEGORIES
      SELECT custom_fields.*,
             mapped_categories.discourse_id AS discourse_category_id
      FROM category_custom_fields custom_fields
           JOIN mapped.ids mapped_categories
              ON custom_fields.category_id = mapped_categories.original_id AND mapped_categories.type = ?
    SQL

    private

    def transform_row(row)
      category_id = row[:discourse_category_id]

      return nil unless @existing_custom_fields.add?("#{category_id}:#{row[:name]}")

      row[:category_id] = category_id

      super
    end
  end
end
