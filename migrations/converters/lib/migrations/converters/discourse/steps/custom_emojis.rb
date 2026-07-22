# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class CustomEmojis < Conversion::Step
        DANGLING_UPLOAD_LOG_MESSAGE = "Custom emoji skipped: its upload is missing"

        source do
          def max_progress
            @source_db.count <<~SQL
              SELECT COUNT(*) FROM custom_emojis
            SQL
          end

          def items
            # The join hands the upload's columns to the processor (prefixed, so
            # they can't collide with the emoji's own — `user_id` in particular),
            # which registers the upload and stores the returned reference — the
            # emoji image must be fetched like any other upload before the
            # importer can create the emoji from it.
            # LEFT JOIN so every emoji row arrives even when its upload is missing;
            # an INNER JOIN would drop those rows and leave the progress short of
            # `max_progress` (which counts every `custom_emojis` row).
            @source_db.query <<~SQL
              SELECT custom_emojis.id,
                     custom_emojis.name,
                     custom_emojis."group",
                     custom_emojis.created_at,
                     uploads.url               AS upload_url,
                     uploads.original_filename AS upload_filename,
                     uploads.origin            AS upload_origin
              FROM custom_emojis
                   LEFT JOIN uploads ON uploads.id = custom_emojis.upload_id
              ORDER BY custom_emojis.id
            SQL
          end
        end

        processor do
          def setup
            @upload_creator =
              UploadCreator.new(column_prefix: "upload", upload_type: "custom_emoji")
          end

          def process(item)
            # A dangling upload_id (the upload row was deleted) must be visible, not
            # silently dropped: an emoji without its image can't be imported, so warn
            # and skip rather than write a row that points at nothing.
            if item[:upload_url].nil?
              tracker.log_warning(
                DANGLING_UPLOAD_LOG_MESSAGE,
                details: {
                  id: item[:id],
                  name: item[:name],
                },
              )
              return
            end

            IntermediateDB::CustomEmoji.create(
              original_id: item[:id],
              name: item[:name],
              group: item[:group],
              upload_id: @upload_creator.create_for(item),
              created_at: item[:created_at],
            )
          end
        end
      end
    end
  end
end
