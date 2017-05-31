module Jobs
  class PendingQueuedPostReminder < Jobs::Scheduled

    every 1.hour

    def execute(args)
      return true unless SiteSetting.notify_about_queued_posts_after > 0 && SiteSetting.contact_email

      queued_post_ids = should_notify_ids

      if queued_post_ids.size > 0 && last_notified_id.to_i < queued_post_ids.max
        message = PendingQueuedPostsMailer.notify(count: queued_post_ids.size)
        Email::Sender.new(message, :pending_queued_posts_reminder).send
        self.last_notified_id = queued_post_ids.max
      end

      true
    end

    def should_notify_ids
      QueuedPost.new_posts.visible.where('created_at < ?', SiteSetting.notify_about_queued_posts_after.hours.ago).pluck(:id)
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
