# frozen_string_literal: true

module Migrations::Converters::Discourse
  class UploadCreator
    def initialize(column_prefix:, upload_type: nil)
      @url_column = :"#{column_prefix}_url"
      @filename_column = :"#{column_prefix}_filename"
      @origin_column = :"#{column_prefix}_origin"
      @user_id_column = :"#{column_prefix}_user_id"

      @upload_type = upload_type # TODO Enum
    end

    def create_for(item)
      return if (url_or_path = item[@url_column]).nil?

      if external_upload?(url_or_path)
        ::Migrations::Database::IntermediateDB::Upload.create_for_url(
          url: url_or_path.start_with?("//") ? "https:#{url_or_path}" : url_or_path,
          filename: item[@filename_column],
          type: @upload_type,
          origin: item[@origin_column],
          user_id: item[@user_id_column],
        )
      else
        ::Migrations::Database::IntermediateDB::Upload.create_for_file(
          path: url_or_path,
          filename: item[@filename_column],
          type: @upload_type,
          origin: item[@origin_column],
          user_id: item[@user_id_column],
        )
      end
    end

    private

    def external_upload?(url_or_path)
      url_or_path&.match?(%r{\A(https?:)?//})
    end
  end
end
