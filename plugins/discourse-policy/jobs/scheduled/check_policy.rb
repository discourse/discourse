# frozen_string_literal: true

module Jobs
  class ::DiscoursePolicy::CheckPolicy < ::Jobs::Scheduled
    every 6.hours

    def execute(args = nil)
      sql = <<~SQL
        SELECT p.id
          FROM post_policies pp
          JOIN posts p ON p.id = pp.post_id
          JOIN topics t ON t.id = p.topic_id
         WHERE t.deleted_at IS NULL
           AND p.deleted_at IS NULL
           AND t.archetype = 'regular'
           AND (
             (reminder = 'weekly' AND last_reminded_at < :weekly)
             OR
             (reminder = 'daily' AND last_reminded_at < :daily)
           )
      SQL

      post_ids = DB.query_single(sql, weekly: 1.week.ago, daily: 1.day.ago)

      if post_ids.size > 0
        Post
          .where(id: post_ids)
          .find_each do |post|
            post.post_policy.update(last_reminded_at: Time.zone.now)

            missing_users(post).find_each do |user|
              clear_existing_notification(user, post)
              user.notifications.create!(
                notification_type: Notification.types[:topic_reminder],
                topic_id: post.topic_id,
                post_number: post.post_number,
                data: { topic_title: post.topic.title, display_username: user.username }.to_json,
                high_priority: true,
              )
            end

            users_to_email(post).find_each do |user|
              DiscoursePolicy::PolicyMailer.send_email(user, post)
            end
          end
      end

      PostPolicy
        .where("next_renew_at < ?", Time.zone.now)
        .find_each do |policy|
          policy
            .policy_users
            .accepted
            .where("accepted_at < ?", policy.next_renew_at)
            .update_all(expired_at: Time.zone.now)
          next_renew = policy.renew_start

          if policy.renew_days.to_i < 1 &&
               !PostPolicy.renew_intervals.keys.include?(policy.renew_interval)
            Rails.logger.warn("Invalid policy on post #{policy.post_id}")
          elsif next_renew.present?
            while next_renew < Time.zone.now
              next_renew = calculate_next_renew_date(next_renew, policy)
            end
          end

          policy.update(next_renew_at: next_renew)
        end

      DB.exec <<~SQL,
        UPDATE policy_users pu
           SET expired_at = :now
          FROM post_policies pp
         WHERE pp.id = pu.post_policy_id
           AND pp.renew_start IS NULL
           AND (pp.renew_days  IS NOT NULL OR pp.renew_interval IS NOT NULL)
           AND pu.accepted_at IS NOT NULL
           AND pu.expired_at  IS NULL
           AND pu.revoked_at  IS NULL
           AND
           (
             (pp.renew_days IS NOT NULL AND pu.accepted_at < :now::timestamp - (INTERVAL '1 day' * pp.renew_days::integer)) OR
             (pp.renew_interval = :monthly AND pu.accepted_at < :now::timestamp - (INTERVAL '1 month')) OR
             (pp.renew_interval = :quarterly AND pu.accepted_at < :now::timestamp - (INTERVAL '1 month' * 3)) OR
             (pp.renew_interval = :yearly AND pu.accepted_at < :now::timestamp - (INTERVAL '1 year'))
           )
      SQL
              now: Time.zone.now,
              monthly: PostPolicy.renew_intervals["monthly"],
              quarterly: PostPolicy.renew_intervals["quarterly"],
              yearly: PostPolicy.renew_intervals["yearly"]
    end

    def calculate_next_renew_date(date, policy)
      case policy.renew_interval
      when "monthly"
        date + 1.month
      when "quarterly"
        date + 3.months
      when "yearly"
        date + 1.year
      else
        date + policy.renew_days.to_i.days
      end
    end

    def missing_users(post)
      post.post_policy.not_accepted_by
    end

    def users_to_email(post)
      post.post_policy.emailed_by
    end

    def clear_existing_notification(user, post)
      existing_notification =
        Notification.find_by(
          notification_type: Notification.types[:topic_reminder],
          topic_id: post.topic_id,
          post_number: post.post_number,
          user: user,
        )
      return if existing_notification.blank?
      existing_notification.delete
    end
  end
end
