# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Topics < Conversion::Step
        source do
          def max_progress
            @source_db.count <<~SQL
              SELECT COUNT(*) FROM topics
            SQL
          end

          def items
            @source_db.query <<~SQL
              SELECT t.*,
                     up.url               AS og_image_url,
                     up.original_filename AS og_image_filename,
                     up.origin            AS og_image_origin,
                     up.user_id           AS og_image_user_id
              FROM topics t
                   LEFT JOIN uploads up ON t.og_image_upload_id = up.id
              ORDER BY t.id
            SQL
          end
        end

        processor do
          def setup
            @og_image_upload_creator = UploadCreator.new(column_prefix: "og_image")
          end

          def process(item)
            IntermediateDB::Topic.create(
              original_id: item[:id],
              archetype: item[:archetype],
              archived: item[:archived],
              bannered_until: item[:bannered_until],
              category_id: item[:category_id],
              closed: item[:closed],
              created_at: item[:created_at],
              deleted_at: item[:deleted_at],
              deleted_by_id: item[:deleted_by_id],
              external_id: item[:external_id],
              featured_link: item[:featured_link],
              locale: item[:locale],
              og_image_upload_id: @og_image_upload_creator.create_for(item),
              pinned_at: item[:pinned_at],
              pinned_globally: item[:pinned_globally],
              pinned_until: item[:pinned_until],
              slow_mode_seconds: item[:slow_mode_seconds],
              subtype: item[:subtype],
              title: item[:title],
              user_id: item[:user_id],
              views: item[:views],
              visibility_reason_id: item[:visibility_reason_id],
              visible: item[:visible],
            )
          end
        end
      end
    end
  end
end
