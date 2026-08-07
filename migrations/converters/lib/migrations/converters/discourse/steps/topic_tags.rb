# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class TopicTags < Conversion::Step
        source { reads_table "topic_tags" }

        processor do
          def process(item)
            IntermediateDB::TopicTag.create(
              topic_id: item[:topic_id],
              tag_id: item[:tag_id],
              created_at: item[:created_at],
            )
          end
        end
      end
    end
  end
end
