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
            # The source's `upload_id` is a numeric FK; IntermediateDB references an
            # upload by its content hash, so the join's `sha1` becomes the
            # reference the importer resolves against.
            @source_db.query <<~SQL
              SELECT custom_emojis.id,
                     custom_emojis.name,
                     custom_emojis."group",
                     custom_emojis.created_at,
                     uploads.sha1 AS upload_id
              FROM custom_emojis
                   JOIN uploads ON uploads.id = custom_emojis.upload_id
              ORDER BY custom_emojis.id
            SQL
          end
        end

        processor do
          def process(item)
            IntermediateDB::CustomEmoji.create(
              original_id: item[:id],
              name: item[:name],
              group: item[:group],
              upload_id: item[:upload_id],
              created_at: item[:created_at],
            )
          end
        end
      end
    end
  end
end
