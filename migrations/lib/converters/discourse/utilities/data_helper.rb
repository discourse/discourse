# frozen_string_literal: true

module Migrations::Converters::Discourse
  class DataHelper
    def self.external_upload?(url)
      url&.match?(%r{\A(https?:)?//})
    end

    def self.create_upload(item, column_prefix)
      url = item[:"#{column_prefix}_url"]
      return if url.nil?

      if external_upload?(url)
        ::Migrations::Database::IntermediateDB::Upload.create_for_url(
          url:,
          filename: item[:"#{column_prefix}_filename"],
          type: "avatar", # TODO Enum
          origin: item[:"#{column_prefix}_origin"],
          user_id: item[:"#{column_prefix}_user_id"],
        )
      else
        ::Migrations::Database::IntermediateDB::Upload.create_for_file(
          path: url,
          filename: item[:"#{column_prefix}_filename"],
          type: "avatar", # TODO Enum
          origin: item[:"#{column_prefix}_origin"],
          user_id: item[:"#{column_prefix}_user_id"],
        )
      end
    end
  end
end
