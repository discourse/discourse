# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      # Human-readable item names for reports.
      module Labels
        def self.for(section, item)
          case section
          when "translation_overrides"
            "#{item["locale"]}: #{item["key"]}"
          when "categories"
            item["name"].presence || item.dig("match", "slug_path") || item["match"].to_s
          else
            item["name"].presence || item["match"].to_s
          end
        end
      end
    end
  end
end
