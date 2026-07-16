# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class TagGroupMemberships < Conversion::Step
        source { reads_table "tag_group_memberships" }

        processor do
          def process(item)
            IntermediateDB::TagGroupMembership.create(
              created_at: item[:created_at],
              tag_group_id: item[:tag_group_id],
              tag_id: item[:tag_id],
            )
          end
        end
      end
    end
  end
end
