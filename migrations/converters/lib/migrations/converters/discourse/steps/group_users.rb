# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class GroupUsers < Conversion::ProgressStep
        source do
          # Skip the automatic Trust Level groups.
          reads_table "group_users", where: "group_id NOT IN (10, 11, 12, 13, 14)"
        end

        processor do
          def process(item)
            IntermediateDB::GroupUser.create(
              created_at: item[:created_at],
              group_id: item[:group_id],
              user_id: item[:user_id],
              owner: item[:owner],
              notification_level: item[:notification_level],
            )
          end
        end
      end
    end
  end
end
