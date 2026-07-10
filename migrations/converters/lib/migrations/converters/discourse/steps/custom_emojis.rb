# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class CustomEmojis < Conversion::Step
        source do
          def max_progress
            @source_db.count <<~SQL
              SELECT COUNT(*) FROM custom_emojis
            SQL
          end

          def items
            # The join hands the upload's `url`/`filename`/`origin` to the
            # processor, which registers the upload and stores the returned
            # reference — the emoji image must be fetched like any other upload
            # before the importer can create the emoji from it.
            @source_db.query <<~SQL
              SELECT custom_emojis.id,
                     custom_emojis.name,
                     custom_emojis."group",
                     custom_emojis.created_at,
                     uploads.url,
                     uploads.original_filename AS filename,
                     uploads.origin
              FROM custom_emojis
                   JOIN uploads ON uploads.id = custom_emojis.upload_id
              ORDER BY custom_emojis.id
            SQL
          end
        end

        processor do
          def setup
            @upload_creator = UploadCreator.new(upload_type: "custom_emoji")
          end

          def process(item)
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
