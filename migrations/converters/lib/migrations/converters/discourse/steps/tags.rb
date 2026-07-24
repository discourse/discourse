# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Tags < Conversion::Step
        source { reads_table "tags" }

        processor do
          def process(item)
            IntermediateDB::Tag.create(
              original_id: item[:id],
              created_at: item[:created_at],
              description: item[:description],
              name: item[:name],
              locale: item[:locale],
              slug: item[:slug],
            )

            if item[:target_tag_id]
              IntermediateDB::TagSynonym.create(
                synonym_tag_id: item[:id],
                target_tag_id: item[:target_tag_id],
              )
            end
          end
        end
      end
    end
  end
end
