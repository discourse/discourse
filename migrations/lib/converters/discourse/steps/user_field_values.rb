# frozen_string_literal: true

module Migrations::Converters::Discourse
  class UserFieldValues < ::Migrations::Converters::Base::ProgressStep
    USER_FIELD_PREFIX = "user_field_"

    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM user_custom_fields
        WHERE user_id >= 0
          AND name LIKE '#{USER_FIELD_PREFIX}%'
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT user_custom_fields.*,
               CAST(REPLACE(name, '#{USER_FIELD_PREFIX}', '') AS INTEGER) AS field_id,
               (COUNT(*) OVER (PARTITION BY user_id, name) > 1)           AS is_multiselect_field
        FROM user_custom_fields
        WHERE user_id >= 0
          AND name LIKE '#{USER_FIELD_PREFIX}%'
        ORDER BY user_id, name
      SQL
    end

    def process_item(item)
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
