# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class MutedUsers < Conversion::Step
        source { reads_table "muted_users" }

        processor do
          def process(item)
            IntermediateDB::MutedUser.create(
              muted_user_id: item[:muted_user_id],
              user_id: item[:user_id],
              created_at: item[:created_at],
            )
          end
        end
      end
    end
  end
end
