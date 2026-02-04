# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  class UserSuspensions < ::Migrations::Converters::Base::ProgressStep
    include SqlTransformer

    run_in_parallel(true)

    attr_accessor :source_db, :settings

    def max_progress
      count(<<~SQL, user_type_ignore: Constants::USER_TYPE_IGNORE)
        SELECT COUNT(*)
        FROM phpbb_banlist b
          JOIN phpbb_users u ON (b.ban_userid = u.user_id)
        WHERE b.ban_exclude = 0
          AND u.user_type <> :user_type_ignore
      SQL
    end

    def items
      query(<<~SQL, user_type_ignore: Constants::USER_TYPE_IGNORE)
        SELECT b.ban_userid AS user_id, b.ban_start, b.ban_end, b.ban_reason
        FROM phpbb_banlist b
          JOIN phpbb_users u ON (b.ban_userid = u.user_id)
        WHERE b.ban_exclude = 0
          AND u.user_type <> :user_type_ignore
        ORDER BY b.ban_userid
      SQL
    end

    def process_item(item)
      suspended_at = Time.at(item[:ban_start]).utc
      suspended_till = Time.at(item[:ban_end]).utc if item[:ban_end]&.positive?

      IntermediateDB::UserSuspension.create(
        user_id: item[:user_id],
        suspended_at:,
        suspended_till:,
        reason: item[:ban_reason],
      )
    end
  end
end
