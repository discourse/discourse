# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class TopicAllowedGroups < Conversion::Step
        source { reads_table "topic_allowed_groups" }

        processor do
          def process(item)
            IntermediateDB::TopicAllowedGroup.create(
              topic_id: item[:topic_id],
              group_id: item[:group_id],
            )
          end
        end
      end
    end
  end
end
