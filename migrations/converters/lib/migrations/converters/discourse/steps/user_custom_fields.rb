# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class UserCustomFields < Conversion::ProgressStep
        source do
          def max_progress
            @source_db.count <<~SQL
              SELECT COUNT(*)
              FROM (
                SELECT 1
                FROM user_custom_fields
                WHERE user_id > 0
                  AND value IS NOT NULL
                  AND name NOT LIKE '#{UserFieldValues::USER_FIELD_LIKE_PATTERN}' ESCAPE '\\'
                GROUP BY user_id, name, value
              ) custom_fields
            SQL
          end

          def items
            # User field values are converted by the `UserFieldValues` step.
            # The GROUP BY drops exact duplicates because the IntermediateDB
            # uses (user_id, name, value) as primary key.
            @source_db.query <<~SQL
              SELECT user_id, name, value, MIN(created_at) AS created_at
              FROM user_custom_fields
              WHERE user_id > 0
                AND value IS NOT NULL
                AND name NOT LIKE '#{UserFieldValues::USER_FIELD_LIKE_PATTERN}' ESCAPE '\\'
              GROUP BY user_id, name, value
              ORDER BY user_id, name, value
            SQL
          end
        end

        processor do
          def process(item)
            IntermediateDB::UserCustomField.create(
              user_id: item[:user_id],
              name: item[:name],
              value: item[:value],
              created_at: item[:created_at],
            )
          end
        end
      end
    end
  end
end
