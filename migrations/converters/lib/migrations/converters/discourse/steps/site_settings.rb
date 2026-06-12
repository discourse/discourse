# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class SiteSettings < Conversion::ProgressStep
        source do
          attr_accessor :source_db

          def max_progress
            @source_db.count <<~SQL
              SELECT COUNT(*)
              FROM site_settings
              WHERE name <> 'permalink_normalizations'
            SQL
          end

          def items
            # The uploads referenced by upload-typed settings are embedded into
            # the items because the processor has no access to the source DB.
            # The CASE guards the casts: the planner is free to evaluate them
            # while probing the uploads PK index for rows of other setting
            # types, where the value is not numeric.
            rows = @source_db.query <<~SQL
              SELECT s.name, s.value, s.data_type, s.updated_at, u.uploads
              FROM site_settings s
                   LEFT JOIN LATERAL (
                       SELECT JSONB_AGG(JSONB_BUILD_OBJECT('id', u.id,
                                                           'url', u.url,
                                                           'filename', u.original_filename,
                                                           'origin', u.origin,
                                                           'user_id', u.user_id)) AS uploads
                       FROM uploads u
                       WHERE u.id = ANY (CASE
                                             WHEN s.value = '' THEN NULL
                                             WHEN s.data_type = 17 THEN STRING_TO_ARRAY(s.value, '|')::int[]
                                             WHEN s.data_type = 18 THEN ARRAY[s.value::int]
                                         END)
                       ) u ON TRUE
              WHERE s.name <> 'permalink_normalizations'
              ORDER BY s.name
            SQL

            rows.lazy.map do |row|
              row[:uploads]&.each(&:symbolize_keys!)
              row
            end
          end
        end

        processor do
          def setup
            @upload_creator = UploadCreator.new
          end

          def process(item)
            value =
              case item[:data_type]
              when Enums::SiteSettingDatatype::UPLOAD
                create_uploads([item[:value]], item[:uploads])
              when Enums::SiteSettingDatatype::UPLOADED_IMAGE_LIST
                create_uploads(item[:value].split("|"), item[:uploads])
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

          def create_uploads(upload_ids, uploads)
            uploads_by_id = (uploads || []).index_by { |upload| upload[:id] }

            upload_ids
              .map do |upload_id|
                upload = uploads_by_id[upload_id.to_i]
                upload ? @upload_creator.create_for(upload) : nil
              end
              .compact
              .join("|")
          end
        end
      end
    end
  end
end
