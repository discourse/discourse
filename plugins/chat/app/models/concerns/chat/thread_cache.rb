# frozen_string_literal: true

module Chat
  module ThreadCache
    extend ActiveSupport::Concern

    class_methods do
      def replies_count_cache_updated_at_redis_key(id)
        "chat_thread:replies_count_cache_updated_at:#{id}"
      end

      def replies_count_cache_redis_key(id)
        "chat_thread:replies_count_cache:#{id}"
      end

      def clear_caches!(ids)
        ids = Array.wrap(ids)
        keys_to_delete =
          ids
            .map do |id|
              [replies_count_cache_redis_key(id), replies_count_cache_updated_at_redis_key(id)]
            end
            .flatten
        Discourse.redis.del(keys_to_delete)
      end
    end

    def replies_count_cache_recently_updated?
      replies_count_cache_updated_at.after?(5.minutes.ago)
    end

    def replies_count_cache_updated_at
      Time.at(
        Discourse.redis.get(Chat::Thread.replies_count_cache_updated_at_redis_key(self.id)).to_i,
        in: Time.zone,
      )
    end

    def replies_count_cache
      redis_cache = Discourse.redis.get(Chat::Thread.replies_count_cache_redis_key(self.id))&.to_i
      if redis_cache.present? && redis_cache != self.replies_count
        redis_cache
      else
        self.replies_count
      end
    end

    def set_replies_count_cache(value, update_db: false)
      self.update!(replies_count: value) if update_db
      Discourse.redis.setex(
        Chat::Thread.replies_count_cache_redis_key(self.id),
        5.minutes.from_now.to_i,
        value,
      )
    end

    def increment_replies_count_cache
      Discourse.redis.incr(Chat::Thread.replies_count_cache_redis_key(self.id))
      thread_reply_count_cache_changed
    end

    def decrement_replies_count_cache
      Discourse.redis.decr(Chat::Thread.replies_count_cache_redis_key(self.id))
      thread_reply_count_cache_changed
    end

    def thread_reply_count_cache_changed
      Jobs.enqueue_in(5.seconds, Jobs::Chat::UpdateThreadReplyCount, thread_id: self.id)
      ::Chat::Publisher.publish_thread_original_message_metadata!(self)
    end
  end
end
