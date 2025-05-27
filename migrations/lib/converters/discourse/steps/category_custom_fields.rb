# frozen_string_literal: true

module Migrations::Converters::Discourse
  class CategoryCustomFields < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM category_custom_fields
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT category_id, name, value
        FROM category_custom_fields
      SQL
    end

    def process_item(item)
      IntermediateDB::CategoryCustomField.create(
        category_id: item[:category_id],
        name: item[:name],
        value: item[:value],
      )
    end
  end
end
