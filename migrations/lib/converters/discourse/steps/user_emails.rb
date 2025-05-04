# frozen_string_literal: true

module Migrations::Converters::Discourse
  class UserEmails < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM user_emails
        WHERE user_id >= 0
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT user_id, email, "primary", created_at
        FROM user_emails
        WHERE user_id >= 0
        ORDER BY user_id, email
      SQL
    end

    def process_item(item)
      IntermediateDB::UserEmail.create(
        email: item[:email],
        primary: item[:primary],
        user_id: item[:user_id],
        created_at: item[:created_at],
      )
    end
  end
end
