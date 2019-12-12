# frozen_string_literal: true

module Jobs

  class PendingReviewablesReminder < ::Jobs::Scheduled
    every 1.hour

    attr_reader :sent_reminder

    def execute(args)
      @sent_reminder = false

      if SiteSetting.notify_about_flags_after > 0
        reviewable_ids = Reviewable
          .pending
          .default_visible
          .where('latest_score < ?', SiteSetting.notify_about_flags_after.to_i.hours.ago)
          .order('id DESC')
          .pluck(:id)

        if reviewable_ids.size > 0 && self.class.last_notified_id < reviewable_ids[0]
          usernames = active_moderator_usernames
          mentions = usernames.size > 0 ? "@#{usernames.join(', @')} " : ""

          @sent_reminder = PostCreator.create(
            Discourse.system_user,
            target_group_names: Group[:moderators].name,
            archetype: Archetype.private_message,
            subtype: TopicSubtype.system_message,
            title: I18n.t('reviewables_reminder.subject_template', count: reviewable_ids.size),
            raw: mentions + I18n.t('reviewables_reminder.submitted', count: SiteSetting.notify_about_flags_after, base_path: Discourse.base_path)
          ).present?

          self.class.last_notified_id = reviewable_ids[0]
        end
      end
    end

    def self.last_notified_id
      Discourse.redis.get(last_notified_key).to_i
    end

    def self.last_notified_id=(arg)
      Discourse.redis.set(last_notified_key, arg)
    end

    def self.last_notified_key
      "last_notified_reviewable_id".freeze
    end

    def self.clear_key
      Discourse.redis.del(last_notified_key)
    end

    def active_moderator_usernames
      User.where(moderator: true)
        .human_users
        .order('last_seen_at DESC')
        .limit(3)
        .pluck(:username)
    end

  end

end
