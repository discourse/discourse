# frozen_string_literal: true

module Migrations::Importer::Steps::Base
  class Tags < ::Migrations::Importer::CopyStep
    include ::HasSanitizableFields

    MAX_DESCRIPTION_LENGTH = 1000
    RESERVED_TAGS = Tag::RESERVED_TAGS.to_set.freeze

    class << self
      def inherited(klass)
        super

        klass.requires_mapping :existing_tag_by_name, "SELECT LOWER(name), id FROM tags"
        klass.table_name :tags
        klass.column_names %i[id name description target_tag_id created_at updated_at]
        klass.store_mapped_ids true
      end
    end

    def execute
      max_tag_length = @intermediate_db.query_value("SELECT MAX(LENGTH(name)) FROM tags") || 0
      SiteSetting.max_tag_length = max_tag_length if SiteSetting.max_tag_length < max_tag_length

      load_validation_caches

      super
    end

    def load_validation_caches
      # Override in subclasses if needed
    end

    def apply_transforms(row)
      # Override in subclasses if needed
      row
    end

    private

    def transform_row(row)
      cleaned_name = DiscourseTagging.clean_tag(row[:name])
      name_lower = cleaned_name.downcase
      existing_id = row[:id] = @existing_tag_by_name[name_lower]

      return nil if existing_id

      if !existing_id && RESERVED_TAGS.include?(name_lower)
        puts "    Tag '#{cleaned_name}' is reserved"

        return nil
      end

      row[:name] = cleaned_name
      row[:description] = sanitize_field(row[:description])[0...MAX_DESCRIPTION_LENGTH] if row[
        :description
      ]

      return nil if apply_transforms(row).nil?

      super
    end
  end
end
