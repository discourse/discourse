# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  class UserEmails < ::Migrations::Converters::Base::ProgressStep
    include SqlTransformer

    run_in_parallel(true)

    attr_accessor :source_db, :settings

    def max_progress
      count(<<~SQL, user_type_ignore: Constants::USER_TYPE_IGNORE)
        SELECT COUNT(*)
        FROM phpbb_users u
        WHERE u.user_type <> :user_type_ignore
      SQL
    end

    def items
      query(<<~SQL, user_type_ignore: Constants::USER_TYPE_IGNORE)
        SELECT u.user_id, u.user_email, u.user_regdate
        FROM phpbb_users u
        WHERE u.user_type <> :user_type_ignore
        ORDER BY u.user_id
      SQL
    end

    def process_item(item)
      IntermediateDB::UserEmail.create(
        user_id: item[:user_id],
        email: item[:user_email],
        primary: true,
        created_at: Time.at(item[:user_regdate]).utc,
      )
    end
  end
end
