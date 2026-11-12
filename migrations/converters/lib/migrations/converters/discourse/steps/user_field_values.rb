# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class UserFieldValues < Conversion::Step
        USER_FIELD_PREFIX = "user_field_"

        # `USER_FIELD_PREFIX` as a `LIKE` pattern: the `_` characters are literal
        # here, not single-character wildcards, so they're escaped for use with
        # an `ESCAPE '\'` clause. This keeps the `user_field_*` split between
        # this step and `UserCustomFields` exact and complementary.
        USER_FIELD_LIKE_PATTERN = "#{USER_FIELD_PREFIX.gsub("_") { '\_' }}%"

        source do
          def max_progress
            @source_db.count <<~SQL
              SELECT COUNT(*)
              FROM user_custom_fields
              WHERE user_id > 0
                AND name LIKE '#{USER_FIELD_LIKE_PATTERN}' ESCAPE '\\'
            SQL
          end

          def items
            @source_db.query <<~SQL
              SELECT user_custom_fields.*,
                     CAST(REPLACE(name, '#{USER_FIELD_PREFIX}', '') AS INTEGER) AS field_id,
                     (COUNT(*) OVER (PARTITION BY user_id, name) > 1)           AS is_multiselect_field
              FROM user_custom_fields
              WHERE user_id > 0
                AND name LIKE '#{USER_FIELD_LIKE_PATTERN}' ESCAPE '\\'
              ORDER BY user_id, name
            SQL
          end
        end

        processor do
          def process(item)
            IntermediateDB::UserFieldValue.create(
              created_at: item[:created_at],
              field_id: item[:field_id],
              user_id: item[:user_id],
              value: item[:value],
              is_multiselect_field: item[:is_multiselect_field],
            )
          end
        end
      end
    end
  end
end
