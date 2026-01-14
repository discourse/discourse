# frozen_string_literal: true

module Migrations::Converters::Discourse
  class MutedUsers < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM muted_users
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT * FROM muted_users
      SQL
    end

    def process_item(item)
      IntermediateDB::MutedUser.create(
        muted_user_id: item[:muted_user_id],
        user_id: item[:user_id],
        created_at: item[:created_at],
      )
    end
  end
end
