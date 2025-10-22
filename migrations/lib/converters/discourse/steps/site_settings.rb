# frozen_string_literal: true

module Migrations::Converters::Discourse
  class SiteSettings < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def execute
      super

      @upload_creator = UploadCreator.new

      @uploads_by_id = @source_db.query(<<~SQL).index_by { |row| row[:id] }
        SELECT u.id,
               u.url,
               u.original_filename AS filename,
               u.origin,
               u.user_id
        FROM site_settings s
             JOIN LATERAL (
                      SELECT u.*
                      FROM uploads u
                      WHERE (s.data_type = 17 AND u.id = ANY (STRING_TO_ARRAY(s.value, '|')::int[]))
                         OR (s.data_type = 18 AND u.id = s.value::int)
                      ) u ON TRUE
        WHERE s.value <> ''
      SQL
    end

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM site_settings
        WHERE name <> 'permalink_normalizations'
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT name, value, data_type, updated_at
        FROM site_settings
        WHERE name <> 'permalink_normalizations'
        ORDER BY name
      SQL
    end

    def process_item(item)
      value =
        case item[:data_type]
        when Enums::SiteSettingDatatype::UPLOAD
          create_uploads([item[:value]])
        when Enums::SiteSettingDatatype::UPLOADED_IMAGE_LIST
          create_uploads(item[:value].split("|"))
        else
          item[:value]
        end

      IntermediateDB::SiteSetting.create(
        name: item[:name],
        value:,
        last_changed_at: item[:updated_at],
        import_mode: Enums::SiteSettingImportMode::AUTO,
      )
    end

    private

    def create_uploads(upload_ids)
      upload_ids
        .map do |upload_id|
          upload = @uploads_by_id[upload_id.to_i]
          upload ? @upload_creator.create_for(upload) : nil
        end
        .compact
        .join("|")
    end
  end
end
