# frozen_string_literal: true

module Migrations
  module Importer
    # ID resolution and URL rendering must agree on which path segments are
    # tag names and which are category filters.
    module TagLinkPath
      Enums = Migrations::Database::IntermediateDB::Enums
      private_constant :Enums

      TAG_SUBCATEGORY_FILTERS = %w[none all]
      private_constant :TAG_SUBCATEGORY_FILTERS

      private

      def multi_tag_link?(row)
        row[:target_type] == Enums::LinkTarget::CATEGORY_TAG ||
          row[:target_type] == Enums::LinkTarget::TAG_INTERSECTION
      end

      def tag_path_filter(row)
        return nil unless row[:target_type] == Enums::LinkTarget::CATEGORY_TAG

        segments = row[:target_tag_path].to_s.split("/")
        return nil unless segments.size > 1

        TAG_SUBCATEGORY_FILTERS.include?(segments.first) ? segments.first : nil
      end

      def tag_path_tags(row)
        segments = row[:target_tag_path].to_s.split("/")
        segments.shift if tag_path_filter(row)
        segments
      end
    end
  end
end
