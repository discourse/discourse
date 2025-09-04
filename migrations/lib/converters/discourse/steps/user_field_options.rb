# frozen_string_literal: true

module Migrations::Converters::Discourse
  class UserFieldOptions < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM user_field_options
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM user_field_options
        ORDER BY user_field_id
      SQL
    end

    def process_item(item)
      IntermediateDB::UserFieldOption.create(
        user_field_id: item[:user_field_id],
        value: item[:value],
        created_at: item[:created_at],
      )
    end
  end
end
