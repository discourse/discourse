# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class UserFieldOptions < Conversion::Step
        source { reads_table "user_field_options" }

        processor do
          def process(item)
            IntermediateDB::UserFieldOption.create(
              user_field_id: item[:user_field_id],
              value: item[:value],
              created_at: item[:created_at],
            )
          end
        end
      end
    end
  end
end
