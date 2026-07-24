# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class TagGroupPermissions < Conversion::Step
        source { reads_table "tag_group_permissions" }

        processor do
          def process(item)
            IntermediateDB::TagGroupPermission.create(
              group_id: item[:group_id],
              permission_type: item[:permission_type],
              tag_group_id: item[:tag_group_id],
              created_at: item[:created_at],
            )
          end
        end
      end
    end
  end
end
