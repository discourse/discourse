module Jobs
  class PendingQueuedPostReminder < Jobs::Scheduled

    every 1.hour

    def execute(args)
      return true unless SiteSetting.notify_about_queued_posts_after > 0

      queued_post_ids = should_notify_ids

      if queued_post_ids.size > 0 && last_notified_id.to_i < queued_post_ids.max
        PostCreator.create(
          Discourse.system_user,
          target_group_names: Group[:moderators].name,
          archetype: Archetype.private_message,
          subtype: TopicSubtype.system_message,
          title: I18n.t('system_messages.queued_posts_reminder.subject_template', count: queued_post_ids.size),
          raw: I18n.t('system_messages.queued_posts_reminder.text_body_template', base_url: Discourse.base_url)
        )

        self.last_notified_id = queued_post_ids.max
      end

      true
    end

    def should_notify_ids
      ReviewableQueuedPost.where(status: Reviewable.statuses[:pending]).where(
        'created_at < ?', SiteSetting.notify_about_queued_posts_after.hours.ago
      ).pluck(:id)
    end

    def last_notified_id
      (i = $redis.get(self.class.last_notified_key)) && i.to_i
    end

    def last_notified_id=(arg)
      $redis.set(self.class.last_notified_key, arg)
    end

    def self.last_notified_key
      "last_notified_queued_post_id".freeze
    end
  end
end
