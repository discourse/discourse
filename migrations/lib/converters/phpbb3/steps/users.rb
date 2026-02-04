# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  class Users < ::Migrations::Converters::Base::ProgressStep
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
        SELECT u.user_id, u.username, u.user_regdate, u.user_lastvisit, u.user_ip,
          u.user_type, u.user_inactive_reason, g.group_name, u.user_posts, u.user_birthday
        FROM phpbb_users u
          LEFT OUTER JOIN phpbb_groups g ON (g.group_id = u.group_id)
        WHERE u.user_type <> :user_type_ignore
        ORDER BY u.user_id
      SQL
    end

    def process_item(item)
      created_at = Time.at(item[:user_regdate]).utc
      last_seen_at = Time.at(item[:user_lastvisit]).utc if item[:user_lastvisit]&.positive?

      IntermediateDB::User.create(
        original_id: item[:user_id],
        username: item[:username],
        original_username: item[:username],
        name: item[:username],
        created_at:,
        last_seen_at:,
        first_seen_at: created_at,
        active: item[:user_type] != Constants::USER_TYPE_INACTIVE,
        admin: item[:group_name] == Constants::GROUP_ADMINISTRATORS,
        moderator: item[:group_name] == Constants::GROUP_MODERATORS,
        trust_level: calculate_trust_level(item),
        registration_ip_address: item[:user_ip],
        date_of_birth: parse_birthday(item[:user_birthday]),
      )
    end

    private

    def calculate_trust_level(item)
      case item[:group_name]
      when Constants::GROUP_ADMINISTRATORS, Constants::GROUP_MODERATORS
        4
      else
        item[:user_posts].to_i > 0 ? 1 : 0
      end
    end

    def parse_birthday(birthday_str)
      return nil if birthday_str.blank?

      parts = birthday_str.to_s.split("-").map(&:to_i)
      return nil if parts.length != 3 || parts.any?(&:zero?)

      day, month, year = parts
      return nil if year < 1900 || year > Time.now.year

      Date.new(year, month, day)
    rescue ArgumentError
      nil
    end
  end
end
