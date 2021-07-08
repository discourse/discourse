# frozen_string_literal: true

module Jobs
  class MassAwardBadge < ::Jobs::Base
    def execute(args)
      return unless mode = args[:mode]
      badge = Badge.find_by(id: args[:badge_id])

      users = User.select(:id, :username, :locale)

      email_mode = mode == 'email'
      if email_mode
        args[:users_batch].map!(&:downcase)
        users = users.with_email(args[:users_batch])
      else
        args[:users_batch].map! { |u| User.normalize_username(u) }
        users = users.where(username_lower: args[:users_batch])
      end

      return if users.empty? || badge.nil? || !badge.enabled?

      if args[:grant_existing_holders] && (batch_number = args[:batch_number]) && (jobs_id = args[:jobs_id])
        if email_mode
          emails_or_usernames_map_to_ids = users.pluck('LOWER(user_emails.email)', :id).to_h
        else
          emails_or_usernames_map_to_ids = users.pluck(:username_lower, :id).to_h
        end
        count_per_user = {}
        args[:users_batch].each do |email_or_username|
          id = emails_or_usernames_map_to_ids[email_or_username]
          next if id.blank?
          count_per_user[id] ||= 0
          count_per_user[id] += 1
        end
        BadgeGranter.mass_grant_existing_holders(
          badge,
          count_per_user,
          jobs_id,
          batch_number
        )
      else
        BadgeGranter.mass_grant(badge, users)
      end
    end
  end
end
